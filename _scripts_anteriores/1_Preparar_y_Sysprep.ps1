<#
  1_Preparar_y_Sysprep.ps1
  -----------------------------------------------------------------
  Ejecutar en el EQUIPO DE REFERENCIA (ya personalizado), como
  Administrador. Valida el sistema, limpia y ejecuta Sysprep
  (/generalize /oobe /shutdown). Al terminar el equipo se APAGA:
  NO lo vuelvas a encender en Windows; arranca con Hiren's y usa
  2_Capturar.cmd.

  Parametros opcionales:
    -SinCopyProfile      No copiar el perfil personalizado al usuario por defecto.
    -QuitarAppsProblema  Desinstalar automaticamente las apps de la Store que
                         bloquean Sysprep (instaladas solo para un usuario).
    -LimpiezaProfunda    DISM StartComponentCleanup /ResetBase (lento, reduce
                         el tamano de la imagen; las actualizaciones instaladas
                         ya no se podran desinstalar).
#>
param(
    [switch]$SinCopyProfile,
    [switch]$QuitarAppsProblema,
    [switch]$LimpiezaProfunda
)

$ErrorActionPreference = 'Stop'
function Paso($t)  { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t)    { Write-Host "   [OK] $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "   [!] $t" -ForegroundColor Yellow }
function Fallo($t) { Write-Host "   [X] $t" -ForegroundColor Red; Read-Host "Pulsa Enter para salir"; exit 1 }

$sysprepDir = Join-Path $env:WINDIR 'System32\Sysprep'
$unattend   = Join-Path $sysprepDir 'unattend.xml'

# --- Administrador ------------------------------------------------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fallo "Ejecuta este script como Administrador."
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   PREPARACION DE IMAGEN MAESTRA + SYSPREP"                  -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# --- Dominio ------------------------------------------------------
Paso "Comprobando union a dominio"
if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) {
    Fallo "El equipo esta unido a un dominio. Sacalo del dominio antes de generalizar."
}
Ok "No esta en dominio"

# --- BitLocker ----------------------------------------------------
Paso "Comprobando BitLocker en $env:SystemDrive"
try {
    $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    if ($bl.VolumeStatus -ne 'FullyDecrypted') {
        Fallo "La unidad esta cifrada o descifrandose ($($bl.VolumeStatus)). Ejecuta 'manage-bde -off $env:SystemDrive', espera a que termine (manage-bde -status) y vuelve a lanzar el script."
    }
    Ok "Sin cifrado"
} catch {
    Aviso "No se pudo consultar BitLocker (puede que la edicion no lo tenga). Se continua."
}

# --- Reinicio pendiente -------------------------------------------
Paso "Comprobando reinicios pendientes"
$pendiente = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
             (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
if ($pendiente) { Fallo "Hay un reinicio pendiente por actualizaciones. Reinicia el equipo y vuelve a ejecutar." }
Ok "Sin reinicios pendientes"

# --- Almacenamiento reservado (error 0x800F0975) -------------------
Paso "Comprobando almacenamiento reservado"
$rm = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager'
$escenario = (Get-ItemProperty $rm -Name ActiveScenario -ErrorAction SilentlyContinue).ActiveScenario
Set-ItemProperty $rm -Name ShippedWithReserves -Value 0 -Type DWord -ErrorAction SilentlyContinue
dism.exe /Online /Set-ReservedStorageState /State:Disabled /Quiet | Out-Null
if ($escenario -and $escenario -ne 0) {
    Set-ItemProperty $rm -Name ActiveScenario -Value 0 -Type DWord
    Aviso "El almacenamiento reservado estaba en uso (ActiveScenario=$escenario). Se ha desactivado."
    Fallo "REINICIA el equipo y vuelve a ejecutar este script."
}
Ok "Almacenamiento reservado desactivado"

# --- Apps de la Store que bloquean Sysprep ------------------------
Paso "Buscando apps de la Store que bloquean Sysprep"
$provisionadas = (Get-AppxProvisionedPackage -Online).DisplayName
$problema = Get-AppxPackage -AllUsers | Where-Object {
    -not $_.IsFramework -and -not $_.NonRemovable -and
    $_.SignatureKind -eq 'Store' -and ($provisionadas -notcontains $_.Name)
}
if ($problema) {
    $problema | ForEach-Object { Aviso "$($_.Name)  ($($_.PackageFullName))" }
    if ($QuitarAppsProblema) {
        foreach ($p in $problema) {
            try {
                Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
                Ok "Eliminada: $($p.Name)"
            } catch {
                Aviso "No se pudo eliminar $($p.Name): $($_.Exception.Message)"
            }
        }
    } else {
        Fallo "Estas apps hacen fallar Sysprep. Desinstalalas o vuelve a ejecutar con -QuitarAppsProblema."
    }
} else {
    Ok "Ninguna app problematica"
}

# --- Limpieza -----------------------------------------------------
Paso "Limpiando temporales y papelera"
Remove-Item "$env:TEMP\*", "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Ok "Limpieza basica hecha"

if ($LimpiezaProfunda) {
    Paso "Limpieza profunda de componentes (puede tardar bastante)"
    dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
    if ($LASTEXITCODE -ne 0) { Aviso "DISM devolvio codigo $LASTEXITCODE; se continua." } else { Ok "Componentes limpiados" }
}

# --- unattend.xml (CopyProfile) -----------------------------------
$argsSysprep = @('/generalize', '/oobe', '/shutdown', '/quiet')
if (-not $SinCopyProfile) {
    Paso "Creando unattend.xml con CopyProfile"
    if ($env:USERNAME -ne 'Administrador' -and $env:USERNAME -ne 'Administrator') {
        Aviso "CopyProfile esta pensado para modo auditoria (cuenta Administrador integrada). Usuario actual: $env:USERNAME"
    }
@'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
      publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <CopyProfile>true</CopyProfile>
    </component>
  </settings>
</unattend>
'@ | Set-Content -Path $unattend -Encoding UTF8
    $argsSysprep += "/unattend:$unattend"
    Ok "unattend.xml creado en $unattend"
}

# --- Confirmacion y Sysprep ---------------------------------------
Paso "Listo para ejecutar Sysprep"
Write-Host "   Comando: sysprep.exe $($argsSysprep -join ' ')"
Write-Host "   El equipo se APAGARA al terminar. No lo enciendas en Windows despues." -ForegroundColor Yellow
$r = Read-Host "   Escribe SI para continuar"
if ($r -ne 'SI') { Write-Host "Cancelado."; exit 0 }

Get-Process sysprep -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath (Join-Path $sysprepDir 'sysprep.exe') -ArgumentList $argsSysprep -Wait

# Si llegamos aqui y el equipo no se esta apagando, Sysprep fallo.
Start-Sleep -Seconds 5
$err = Join-Path $sysprepDir 'Panther\setuperr.log'
Write-Host "`nSi el equipo no se apaga, Sysprep ha fallado. Ultimos errores:" -ForegroundColor Red
if (Test-Path $err) { Get-Content $err -Tail 20 }
Write-Host "Log completo: $(Join-Path $sysprepDir 'Panther\setupact.log')"
Read-Host "Pulsa Enter para salir"
