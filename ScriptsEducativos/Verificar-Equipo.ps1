#requires -RunAsAdministrator
<#
Verificar-Equipo.ps1  (se lanza desde IMG3_V2\CuentasCPE.cmd)

Comprueba en un equipo YA desplegado lo que deja el procedimiento CPE, sin
cambiar nada:
  - despliegue: Windows instalado desde la imagen, configuracion inicial
    omitida, tamano y espacio libre de C:
  - particiones: todas las del disco de Windows (recovery, datos de
    programas externos...) y estado del entorno de recuperacion WinRE
  - script de primer arranque: cuentas pendientes de eliminar
  - cuentas: solo AdministradorCPE, administradora
Guarda un informe en ScriptsEducativos\Logs\Verificacion-<equipo>-<fecha>.txt
#>
$ErrorActionPreference = 'Stop'
$nomAdmin = 'AdministradorCPE'

$dirLogs = Join-Path $PSScriptRoot 'Logs'
New-Item -ItemType Directory -Force -Path $dirLogs | Out-Null
$informe = Join-Path $dirLogs ('Verificacion-{0}-{1}.txt' -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:lineas = @()
$script:nOk = 0; $script:nAviso = 0; $script:nFallo = 0

function Escribir([string]$t, [string]$c = 'Gray') { Write-Host $t -ForegroundColor $c; $script:lineas += $t }
function Seccion([string]$t) { Escribir ''; Escribir "== $t" 'Cyan' }
function Ok([string]$t)    { $script:nOk++;    Escribir "   [OK] $t" 'Green' }
function Aviso([string]$t) { $script:nAviso++; Escribir "   [!]  $t" 'Yellow' }
function Fallo([string]$t) { $script:nFallo++; Escribir "   [X]  $t" 'Red' }
function Info([string]$t)  { Escribir "   [i]  $t" 'DarkGray' }

# Pertenencia a grupos por SID (las rutas ADSI incluyen WORKGROUP y no sirven para comparar).
function EsMiembro([string]$sidGrupo, $usuario) {
    if (-not $usuario) { return $false }
    $g = Get-LocalGroup | Where-Object { $_.SID.Value -eq $sidGrupo }
    $adsi = [ADSI]"WinNT://$env:COMPUTERNAME/$($g.Name),group"
    foreach ($m in @($adsi.Invoke('Members'))) {
        try {
            $bytes = $m.GetType().InvokeMember('objectSid', 'GetProperty', $null, $m, $null)
            if ((New-Object Security.Principal.SecurityIdentifier($bytes, 0)).Value -eq $usuario.SID.Value) { return $true }
        } catch {}
    }
    return $false
}

Escribir "VERIFICACION DEL EQUIPO CPE"
Escribir ("Equipo: {0}   Fecha: {1}   Usuario: {2}" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyy-MM-dd HH:mm'), $env:USERNAME)

# ---------------------------------------------------------------------
Seccion 'Despliegue de Windows'
try {
    $estado = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Stop).ImageState
    if ($estado -eq 'IMAGE_STATE_COMPLETE') { Ok "Windows termino de instalarse desde la imagen ($estado)" }
    else { Aviso "Estado de la instalacion: $estado" }
} catch { Aviso 'No se pudo leer el estado de la instalacion.' }

$panther = Join-Path $env:WINDIR 'Panther\unattend.xml'
if ((Test-Path $panther) -and (Select-String -LiteralPath $panther -SimpleMatch 'HideLocalAccountScreen' -Quiet)) {
    Ok 'Se aplico el archivo de respuesta que omite la configuracion inicial'
} else {
    Aviso 'No se encontro el archivo de respuesta que omite la configuracion inicial (Panther\unattend.xml).'
}
$cVol = Get-Volume -DriveLetter $env:SystemDrive.Substring(0, 1)
$libreGB = [math]::Round($cVol.SizeRemaining / 1GB, 1)
$msgC = "Unidad C: de $([math]::Round($cVol.Size / 1GB, 1)) GB ($libreGB GB libres)"
if ($libreGB -ge 10) { Ok $msgC } else { Aviso "$($msgC): queda poco espacio libre" }

# ---------------------------------------------------------------------
Seccion 'Todas las particiones del disco de Windows'
# Recovery y datos del equipo de referencia viajan en la imagen como
# PARTICION_<n> y el despliegue las recrea: aqui se listan para comprobarlas.
try {
    $tipos = @{
        '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' = 'EFI de arranque'
        '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' = 'Reservada MSR'
        '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' = 'Datos'
        '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' = 'Recuperacion'
    }
    $discoWin = (Get-Partition -DriveLetter $env:SystemDrive.Substring(0, 1)).DiskNumber
    foreach ($q in Get-Partition -DiskNumber $discoWin | Sort-Object PartitionNumber) {
        $tipo = $tipos[[string]$q.GptType]; if (-not $tipo) { $tipo = if ($q.MbrType) { "MBR 0x{0:X2}" -f $q.MbrType } else { [string]$q.GptType } }
        $vq = $q | Get-Volume -ErrorAction SilentlyContinue
        $et = ''; if ($vq -and $vq.FileSystemLabel) { $et = " '$($vq.FileSystemLabel)'" }
        $le = ''; if ($q.DriveLetter) { $le = " en $($q.DriveLetter):" }
        $us = ''; if ($vq -and $vq.Size) { $us = (", {0:N1} GB usados" -f (($vq.Size - $vq.SizeRemaining) / 1GB)) }
        Info ("Particion {0}: {1}{2}, {3:N1} GB{4}{5}" -f $q.PartitionNumber, $tipo, $et, ($q.Size / 1GB), $us, $le)
    }
    Info 'Compara esta lista con "Revisar particiones" del equipo de referencia.'
} catch { Aviso "No se pudieron listar las particiones: $($_.Exception.Message)" }
try {
    $re = (& reagentc.exe /info 2>$null) -join "`n"
    if ($re -match '(Enabled|Habilitado)') { Ok 'Entorno de recuperacion de Windows (WinRE) habilitado' }
    else { Aviso 'WinRE no esta habilitado (reagentc /info). Si el equipo de referencia tenia particion de recuperacion, revisalo.' }
} catch { Aviso 'No se pudo consultar WinRE (reagentc /info).' }

# ---------------------------------------------------------------------
Seccion 'Script de primer arranque'
$listaPend = Join-Path $env:WINDIR 'Setup\Scripts\CPE-EliminarCuentas.txt'
$logPrimer = Join-Path $env:WINDIR 'Logs\CPE-Contenidos.log'
if (Test-Path $listaPend) { Fallo "Siguen pendientes de eliminar: $((Get-Content $listaPend) -join ', ') (el script de primer arranque no se ejecuto)" }
elseif (Test-Path $logPrimer) {
    Ok 'El script de primer arranque se ejecuto'
    Get-Content -LiteralPath $logPrimer -Tail 3 | ForEach-Object { Info $_ }
} else { Info 'No habia cuentas pendientes de eliminar en el primer arranque.' }

# ---------------------------------------------------------------------
Seccion 'Cuentas'
$adm = Get-LocalUser -Name $nomAdmin -ErrorAction SilentlyContinue
if (-not $adm) { Fallo "No existe la cuenta $nomAdmin" }
else {
    Ok "Existe la cuenta $nomAdmin"
    if ($adm.Enabled) { Ok "$nomAdmin esta habilitada" } else { Fallo "$nomAdmin esta deshabilitada" }
    if (EsMiembro 'S-1-5-32-544' $adm) { Ok "$nomAdmin es administradora" } else { Fallo "$nomAdmin NO es administradora" }
    if ($adm.PasswordRequired -or $adm.PasswordLastSet) { Info "$nomAdmin tiene contrasena (se eligio en Preparar)" }
    else { Info "$nomAdmin no tiene contrasena (se eligio en Preparar)" }
}
# Solo debe quedar AdministradorCPE; las integradas de Windows no cuentan.
$otras = @(Get-LocalUser | Where-Object { $_.Name -ne $nomAdmin -and $_.SID.Value -notmatch '-(500|501|503|504)$' })
if ($otras.Count) {
    foreach ($o in $otras) { Fallo ("Sobra la cuenta {0} (habilitada: {1}); solo debe existir {2}" -f $o.Name, $(if ($o.Enabled) { 'si' } else { 'no' }), $nomAdmin) }
} else { Ok "No hay otras cuentas: solo existe $nomAdmin" }
foreach ($i in @(Get-LocalUser | Where-Object { $_.SID.Value -match '-(500|501|503|504)$' })) {
    if ($i.Enabled) { Aviso "La cuenta integrada $($i.Name) esta habilitada" }
}

# ---------------------------------------------------------------------
Seccion 'Resultado'
Escribir ("   Correctas: {0}   Avisos: {1}   Fallos: {2}" -f $script:nOk, $script:nAviso, $script:nFallo)
if ($script:nFallo -eq 0 -and $script:nAviso -eq 0) { Escribir '   TODO CORRECTO.' 'Green' }
elseif ($script:nFallo -eq 0) { Escribir '   CORRECTO CON AVISOS: revisa las lineas [!].' 'Yellow' }
else { Escribir '   HAY FALLOS: revisa las lineas [X].' 'Red' }
Escribir ''
Escribir '   Falta comprobar a mano:'
Escribir '    - que el equipo arranca directo al inicio de sesion con AdministradorCPE'
Escribir '    - que las particiones de datos tienen los archivos de los programas externos'
try { $script:lineas | Set-Content -LiteralPath $informe -Encoding UTF8; Write-Host "`nInforme guardado en: $informe" } catch {}
if ($script:nFallo) { exit 1 }
exit 0
