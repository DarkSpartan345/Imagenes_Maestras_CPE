@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Imagen maestra
rem ==========================================================
rem  ImagenMaestra.cmd  -  script unico
rem
rem  Sin parametros abre la interfaz grafica (si no se puede,
rem  muestra el menu de texto). Tambien se puede llamar
rem  directamente con la accion:
rem
rem    ImagenMaestra.cmd preparar  [-SinCopyProfile] [-QuitarAppsProblema] [-LimpiezaProfunda]
rem    ImagenMaestra.cmd capturar  [-Origen D:] [-Nombre x] [-Descripcion "y"] [-Dividir]
rem    ImagenMaestra.cmd desplegar [-Imagen ruta.wim] [-Indice 1] [-Disco 1] [-Firmware UEFI o BIOS]
rem    ImagenMaestra.cmd gui       (interfaz grafica)
rem    ImagenMaestra.cmd menu      (menu de texto)
rem    ImagenMaestra.cmd ayuda
rem
rem  (tambien valen los numeros 1, 2 y 3)
rem
rem  -Auto: no hace preguntas ni pausas (lo usa la interfaz
rem  grafica). Si falta algun dato necesario, termina con error.
rem
rem  Al final del archivo, tras las lineas marcadoras, estan la
rem  parte de PowerShell de "preparar" y la interfaz grafica.
rem ==========================================================

set "SELF=%~f0"
set "BASE=%~dp0"
set "UNIDAD=%~d0"
set "ENPE=0"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\MiniNT" >nul 2>&1 && set "ENPE=1"

set "AUTO=0"
set "OPCS="
for %%v in (P_ORIGEN P_NOMBRE P_DESC P_DIVIDIR P_IMAGEN P_INDICE P_DISCO P_FIRMWARE) do set "%%v="

set "ACCION=%~1"
if not defined ACCION goto :gui

rem --- Resto de parametros --------------------------------
rem  Los conocidos se guardan en P_*; el resto (opciones de
rem  "preparar") se pasan tal cual en OPCS.
:leer_args
shift
if "%~1"=="" goto :ejecutar_args
if /i "%~1"=="-Auto"        (set "AUTO=1" & goto :leer_args)
if /i "%~1"=="-Dividir"     (set "P_DIVIDIR=1" & goto :leer_args)
if /i "%~1"=="-Origen"      (set "P_ORIGEN=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Nombre"      (set "P_NOMBRE=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Descripcion" (set "P_DESC=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Imagen"      (set "P_IMAGEN=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Indice"      (set "P_INDICE=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Disco"       (set "P_DISCO=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Firmware"    (set "P_FIRMWARE=%~2" & shift & goto :leer_args)
set "OPCS=!OPCS! %~1"
goto :leer_args

:ejecutar_args
call :lanzar "%ACCION%"
exit /b %errorlevel%


rem ==========================================================
rem  INTERFAZ GRAFICA (PowerShell + WinForms, al final del archivo)
rem ==========================================================
:gui
if "%ENPE%"=="0" (
  fltmc >nul 2>&1
  if errorlevel 1 (
    echo Solicitando permisos de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%SELF%' -ArgumentList 'gui' -Verb RunAs"
    if errorlevel 1 goto :menu
    exit /b 0
  )
)
set "GUIPS=%TEMP%\ImagenMaestra_gui.ps1"
call :extraer_ps GUI "%GUIPS%"
if errorlevel 1 goto :gui_fallo
powershell -NoProfile -STA -ExecutionPolicy Bypass -File "%GUIPS%" -Script "%SELF%"
if errorlevel 1 goto :gui_fallo
del "%GUIPS%" 2>nul
exit /b 0

:gui_fallo
del "%GUIPS%" 2>nul
echo.
echo [AVISO] No se pudo abrir la interfaz grafica. Se usa el menu de texto.
pause
goto :menu


rem ==========================================================
rem  MENU DE TEXTO
rem ==========================================================
:menu
cls
echo.
echo ==========================================================
echo    IMAGEN MAESTRA DE WINDOWS
echo ==========================================================
if "%ENPE%"=="1" (echo    Entorno detectado: WinPE / Hiren's) else (echo    Entorno detectado: Windows)
echo.
echo    [1] Preparar y Sysprep   (Windows, equipo de referencia)
echo    [2] Capturar imagen      (Hiren's, equipo de referencia)
echo    [3] Desplegar imagen     (Hiren's, equipo de destino)
echo    [4] Ayuda
echo    [5] Interfaz grafica
echo    [0] Salir
echo.
set "OPC="
set /p OPC="Elige una opcion: "
if "%OPC%"=="0" exit /b 0
if "%OPC%"=="1" goto :menu_preparar
if "%OPC%"=="2" (call :lanzar capturar & goto :menu)
if "%OPC%"=="3" (call :lanzar desplegar & goto :menu)
if "%OPC%"=="4" (call :ayuda & pause & goto :menu)
if "%OPC%"=="5" goto :gui
goto :menu

:menu_preparar
set "OPCS="
echo.
set "R=N"
set /p R="Quitar automaticamente las apps de la Store que bloquean Sysprep? S/N [N]: "
if /i "%R%"=="S" set "OPCS=!OPCS! -QuitarAppsProblema"
set "R=N"
set /p R="Limpieza profunda de componentes (lenta, reduce la imagen)? S/N [N]: "
if /i "%R%"=="S" set "OPCS=!OPCS! -LimpiezaProfunda"
set "R=S"
set /p R="Copiar el perfil personalizado al usuario por defecto (CopyProfile)? S/N [S]: "
if /i "%R%"=="N" set "OPCS=!OPCS! -SinCopyProfile"
call :lanzar preparar
rem 99 = se relanzo como administrador en otra ventana
if "%errorlevel%"=="99" exit /b 0
goto :menu


rem ==========================================================
rem  DESPACHADOR
rem ==========================================================
:lanzar
if /i "%~1"=="1"         goto :preparar
if /i "%~1"=="preparar"  goto :preparar
if /i "%~1"=="2"         goto :capturar
if /i "%~1"=="capturar"  goto :capturar
if /i "%~1"=="3"         goto :desplegar
if /i "%~1"=="desplegar" goto :desplegar
if /i "%~1"=="gui"       goto :gui
if /i "%~1"=="menu"      goto :menu
if /i "%~1"=="ayuda"     goto :ayuda
if /i "%~1"=="/?"        goto :ayuda
echo [X] Accion desconocida: %~1
echo.
call :ayuda
exit /b 1


rem ==========================================================
rem  AYUDA
rem ==========================================================
:ayuda
echo.
echo  Uso: ImagenMaestra.cmd [accion] [opciones]
echo.
echo    (sin accion)   Abre la interfaz grafica (o el menu si no se puede).
echo    gui            Abre la interfaz grafica.
echo    menu           Muestra el menu de texto.
echo    preparar   1   En Windows, equipo de referencia. Valida, limpia y
echo                   ejecuta Sysprep. Opciones:
echo                     -QuitarAppsProblema  Quita las apps de la Store que bloquean Sysprep
echo                     -LimpiezaProfunda    DISM /StartComponentCleanup /ResetBase
echo                     -SinCopyProfile      No copiar el perfil al usuario por defecto
echo    capturar   2   En Hiren's, equipo de referencia. Crea Imagenes\^<nombre^>.wim
echo                     -Origen D:  -Nombre x  -Descripcion "y"  -Dividir
echo    desplegar  3   En Hiren's, equipo de destino. BORRA un disco y aplica una imagen.
echo                     -Imagen ruta.wim  -Indice 1  -Disco 1  -Firmware UEFI/BIOS
echo.
echo    -Auto          Sin preguntas ni pausas (lo usa la interfaz grafica).
echo.
echo  Ejemplo: ImagenMaestra.cmd preparar -QuitarAppsProblema -LimpiezaProfunda
echo.
exit /b 0


rem ==========================================================
rem  1) PREPARAR Y SYSPREP  (ejecuta el PowerShell del final)
rem ==========================================================
:preparar
setlocal
if "%ENPE%"=="1" (
  echo.
  echo [X] "Preparar" se ejecuta en el Windows del equipo de referencia, no en Hiren's.
  call :pausa
  exit /b 1
)

rem --- Pedir permisos de administrador si hace falta --------
fltmc >nul 2>&1
if errorlevel 1 (
  if "%AUTO%"=="1" (
    echo [X] Hacen falta permisos de administrador.
    exit /b 1
  )
  echo Solicitando permisos de administrador...
  powershell -NoProfile -Command "Start-Process -FilePath '%SELF%' -ArgumentList 'preparar%OPCS%' -Verb RunAs"
  exit /b 99
)

set "EXTRA="
if "%AUTO%"=="1" set "EXTRA=-Confirmado"
set "PS1=%TEMP%\ImagenMaestra_preparar.ps1"
call :extraer_ps PS1 "%PS1%"
if errorlevel 1 (
  echo [X] No se pudo extraer la parte de PowerShell.
  call :pausa
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %OPCS% %EXTRA%
set "RC=%errorlevel%"
del "%PS1%" 2>nul
call :pausa
exit /b %RC%


rem ==========================================================
rem  2) CAPTURAR  (desde Hiren's)
rem ==========================================================
:capturar
setlocal
title Captura de imagen maestra
call :avisar_si_no_pe || exit /b 1

set "DEST=%BASE%Imagenes"
set "LOGS=%BASE%Logs"
set "SCR=%BASE%Scratch"
if not exist "%DEST%" md "%DEST%"
if not exist "%LOGS%" md "%LOGS%"
if not exist "%SCR%"  md "%SCR%"

echo.
echo ==========================================================
echo    CAPTURA DE IMAGEN MAESTRA
echo ==========================================================
echo.
echo Buscando particiones con Windows...
set N=0
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
  if exist "%%d:\Windows\System32\config\SYSTEM" (
    if /i not "%%d:"=="%UNIDAD%" (
      set /a N+=1
      set "WIN!N!=%%d:"
      echo    [!N!] %%d:\
    )
  )
)

if defined P_ORIGEN (
  set "SRC=%P_ORIGEN:~0,2%"
  if not exist "!SRC!\Windows\System32\config\SYSTEM" (
    echo [X] En !SRC! no hay una instalacion de Windows.
    goto :cap_error
  )
  goto :cap_tengo_src
)
if %N%==0 (
  echo [X] No se encontro ninguna particion con Windows.
  goto :cap_error
)
if %N%==1 (
  set "SRC=%WIN1%"
  goto :cap_tengo_src
)
:cap_elegir_src
if "%AUTO%"=="1" (
  echo [X] Hay varias particiones con Windows: indica cual con -Origen.
  goto :cap_error
)
set "SEL="
set /p SEL="Numero de la particion a capturar: "
set "SRC=!WIN%SEL%!"
if not defined SRC goto :cap_elegir_src
:cap_tengo_src
echo.
echo Particion de origen: %SRC%

rem --- Comprobar que se ejecuto Sysprep --------------------
if not exist "%SRC%\Windows\System32\Sysprep\Sysprep_succeeded.tag" (
  echo.
  echo [AVISO] No se encontro la marca de Sysprep en %SRC%.
  echo     Puede que NO se ejecutara Sysprep o que Windows se arrancara despues.
  echo     Una imagen sin generalizar puede dar problemas en otros equipos.
  if not "%AUTO%"=="1" (
    set "CONT="
    set /p CONT="Continuar de todos modos? S/N: "
    if /i not "!CONT!"=="S" goto :cap_error
  )
)

rem --- Nombre y descripcion --------------------------------
:cap_pedir_nombre
echo.
set "NOMBRE=maestra"
if defined P_NOMBRE (set "NOMBRE=%P_NOMBRE%") else (set /p NOMBRE="Nombre de la imagen [maestra]: ")
if exist "%DEST%\%NOMBRE%.wim" (
  echo [AVISO] Ya existe %NOMBRE%.wim en %DEST%. Elige otro nombre.
  if defined P_NOMBRE goto :cap_error
  goto :cap_pedir_nombre
)
set "DESC=Imagen maestra"
if defined P_DESC (set "DESC=%P_DESC%") else (set /p DESC="Descripcion [Imagen maestra]: ")

echo.
echo ----------------------------------------------------------
echo  Origen : %SRC%\
echo  Destino: %DEST%\%NOMBRE%.wim
echo  Log    : %LOGS%\captura_%NOMBRE%.log
echo ----------------------------------------------------------
if "%AUTO%"=="1" goto :cap_iniciar
set "OK="
set /p OK="Iniciar captura? S/N: "
if /i not "%OK%"=="S" goto :cap_error

:cap_iniciar
echo.
echo Capturando... esto puede tardar entre 20 y 60 minutos.
dism /Capture-Image /ImageFile:"%DEST%\%NOMBRE%.wim" /CaptureDir:%SRC%\ /Name:"%NOMBRE%" /Description:"%DESC%" /Compress:max /CheckIntegrity /Verify /ScratchDir:"%SCR%" /LogPath:"%LOGS%\captura_%NOMBRE%.log"
if errorlevel 1 (
  echo.
  echo [X] DISM fallo. Revisa %LOGS%\captura_%NOMBRE%.log
  goto :cap_error
)

echo.
echo [OK] Imagen creada: %DEST%\%NOMBRE%.wim
dism /Get-ImageInfo /ImageFile:"%DEST%\%NOMBRE%.wim"

rem --- Division opcional para USB FAT32 --------------------
echo.
set "DIV=N"
if defined P_DIVIDIR set "DIV=S"
if "%AUTO%"=="1" goto :cap_dividir
if defined P_DIVIDIR goto :cap_dividir
set /p DIV="Crear tambien copia dividida .swm para USB de instalacion FAT32? S/N [N]: "
:cap_dividir
if /i "%DIV%"=="S" (
  echo Creando copia dividida .swm...
  if not exist "%DEST%\%NOMBRE%_swm" md "%DEST%\%NOMBRE%_swm"
  dism /Split-Image /ImageFile:"%DEST%\%NOMBRE%.wim" /SWMFile:"%DEST%\%NOMBRE%_swm\install.swm" /FileSize:3800
  if errorlevel 1 (
    echo [AVISO] No se pudo dividir la imagen.
  ) else (
    echo [OK] Archivos .swm en %DEST%\%NOMBRE%_swm
  )
)

rmdir /s /q "%SCR%" 2>nul
echo.
echo ==========================================================
echo  CAPTURA TERMINADA
echo ==========================================================
call :pausa
exit /b 0

:cap_error
rmdir /s /q "%SCR%" 2>nul
echo.
echo Proceso cancelado o con errores.
call :pausa
exit /b 1


rem ==========================================================
rem  3) DESPLEGAR  (desde Hiren's, en el equipo de destino)
rem ==========================================================
:desplegar
setlocal
title Despliegue de imagen maestra
call :avisar_si_no_pe || exit /b 1

set "IMGDIR=%BASE%Imagenes"
set "DRVDIR=%BASE%Drivers"
set "RESP=%BASE%Respuesta\unattend.xml"
set "LOGS=%BASE%Logs"
set "DP=%TEMP%\dp_despliegue.txt"
if not exist "%LOGS%" md "%LOGS%"

echo.
echo ==========================================================
echo    DESPLIEGUE DE IMAGEN MAESTRA
echo ==========================================================

rem --- Modo de firmware ------------------------------------
set "MODO="
for /f "tokens=3" %%a in ('reg query HKLM\System\CurrentControlSet\Control /v PEFirmwareType 2^>nul ^| find "PEFirmwareType"') do (
  if "%%a"=="0x2" set "MODO=UEFI"
  if "%%a"=="0x1" set "MODO=BIOS"
)
if defined P_FIRMWARE set "MODO=%P_FIRMWARE%"
if not defined MODO (
  if "%AUTO%"=="1" (
    echo [X] No se pudo detectar el firmware: indica -Firmware UEFI o BIOS.
    goto :dep_error
  )
  set /p MODO="No se pudo detectar el firmware. Escribe UEFI o BIOS: "
)
if /i not "%MODO%"=="UEFI" if /i not "%MODO%"=="BIOS" (
  echo [X] Modo no valido: %MODO%
  goto :dep_error
)
echo.
echo Firmware: %MODO%

rem --- Elegir imagen ---------------------------------------
if defined P_IMAGEN (
  if not exist "%P_IMAGEN%" (
    echo [X] No existe la imagen !P_IMAGEN!
    goto :dep_error
  )
  set "WIM=%P_IMAGEN%"
  goto :dep_tengo_wim
)
echo.
echo Imagenes disponibles en %IMGDIR%:
set N=0
for %%f in ("%IMGDIR%\*.wim") do (
  set /a N+=1
  set "IMG!N!=%%~ff"
  echo    [!N!] %%~nxf
)
if %N%==0 (
  echo [X] No hay archivos .wim en %IMGDIR%
  goto :dep_error
)
if %N%==1 (
  set "WIM=%IMG1%"
  goto :dep_tengo_wim
)
:dep_elegir_wim
if "%AUTO%"=="1" (
  echo [X] Hay varias imagenes: indica cual con -Imagen.
  goto :dep_error
)
set "SEL="
set /p SEL="Numero de la imagen: "
set "WIM=!IMG%SEL%!"
if not defined WIM goto :dep_elegir_wim
:dep_tengo_wim
echo Imagen: %WIM%

dism /Get-ImageInfo /ImageFile:"%WIM%"
set "IDX=1"
if defined P_INDICE (set "IDX=%P_INDICE%") else (set /p IDX="Indice a aplicar [1]: ")

rem --- Detectar el disco que contiene este script ----------
set "LETRA=%UNIDAD:~0,1%"
set "USBDISK="
> "%DP%" (
  echo select volume %LETRA%
  echo detail volume
)
for /f "tokens=1-3" %%a in ('diskpart /s "%DP%"') do (
  if "%%a"=="*" set "USBDISK=%%c"
)

rem --- Elegir disco de destino -----------------------------
echo.
> "%DP%" echo list disk
diskpart /s "%DP%"
echo.
if defined USBDISK echo [i] El disco %USBDISK% contiene las imagenes y NO se puede elegir.
:dep_elegir_disco
set "DISK="
if defined P_DISCO set "DISK=%P_DISCO%"
if not defined DISK if "%AUTO%"=="1" (
  echo [X] Falta el disco de destino: indica -Disco.
  goto :dep_error
)
if not defined DISK set /p DISK="Numero del disco DESTINO, se borrara por completo: "
echo %DISK%| findstr /r "^[0-9][0-9]*$" >nul || (
  if defined P_DISCO (
    echo [X] Numero de disco no valido: %P_DISCO%
    goto :dep_error
  )
  goto :dep_elegir_disco
)
if "%DISK%"=="%USBDISK%" (
  echo [X] Ese es el disco con las imagenes. Elige otro.
  if defined P_DISCO goto :dep_error
  goto :dep_elegir_disco
)

> "%DP%" (
  echo select disk %DISK%
  echo detail disk
)
diskpart /s "%DP%"
echo.
echo ***********************************************************
echo  ATENCION: se BORRARA TODO el contenido del disco %DISK%.
echo ***********************************************************
rem En modo -Auto la confirmacion ya la hizo la interfaz grafica.
if "%AUTO%"=="1" goto :dep_letras
set "CONF="
set /p CONF="Escribe BORRAR para continuar: "
if not "%CONF%"=="BORRAR" goto :dep_error

rem --- Letras libres para las particiones ------------------
:dep_letras
set "LS="
for %%l in (S R Q P O) do if not defined LS if not exist %%l:\ set "LS=%%l"
set "LW="
for %%l in (W V U T N) do if not defined LW if not exist %%l:\ set "LW=%%l"
if not defined LS goto :dep_sin_letras
if not defined LW goto :dep_sin_letras

rem --- Particionar -----------------------------------------
echo.
echo Particionando disco %DISK% en modo %MODO%...
if /i "%MODO%"=="UEFI" (
  > "%DP%" (
    echo select disk %DISK%
    echo clean
    echo convert gpt
    echo create partition efi size=300
    echo format quick fs=fat32 label="System"
    echo assign letter=%LS%
    echo create partition msr size=16
    echo create partition primary
    echo format quick fs=ntfs label="Windows"
    echo assign letter=%LW%
    echo exit
  )
) else (
  > "%DP%" (
    echo select disk %DISK%
    echo clean
    echo convert mbr
    echo create partition primary size=500
    echo format quick fs=ntfs label="System"
    echo active
    echo assign letter=%LS%
    echo create partition primary
    echo format quick fs=ntfs label="Windows"
    echo assign letter=%LW%
    echo exit
  )
)
diskpart /s "%DP%"
if errorlevel 1 (
  echo [X] Error al particionar el disco.
  goto :dep_error
)
if not exist %LW%:\ (
  echo [X] La particion de Windows %LW%: no esta disponible.
  goto :dep_error
)

rem --- Aplicar imagen --------------------------------------
echo.
echo Aplicando imagen en %LW%: ... puede tardar entre 10 y 40 minutos.
dism /Apply-Image /ImageFile:"%WIM%" /Index:%IDX% /ApplyDir:%LW%:\ /CheckIntegrity /LogPath:"%LOGS%\despliegue.log"
if errorlevel 1 (
  echo [X] Error al aplicar la imagen. Revisa %LOGS%\despliegue.log
  goto :dep_error
)

rem --- Drivers opcionales ----------------------------------
if exist "%DRVDIR%\*" (
  echo.
  echo Inyectando drivers de %DRVDIR%...
  dism /Image:%LW%:\ /Add-Driver /Driver:"%DRVDIR%" /Recurse /LogPath:"%LOGS%\drivers.log"
  if errorlevel 1 echo [AVISO] Algunos drivers no se pudieron agregar. Revisa %LOGS%\drivers.log
)

rem --- Archivo de respuesta opcional -----------------------
if exist "%RESP%" (
  echo.
  echo Copiando archivo de respuesta para automatizar la configuracion inicial...
  if not exist "%LW%:\Windows\Panther" md "%LW%:\Windows\Panther"
  copy /y "%RESP%" "%LW%:\Windows\Panther\unattend.xml" >nul
)

rem --- Arranque --------------------------------------------
echo.
echo Creando archivos de arranque...
bcdboot %LW%:\Windows /s %LS%: /f %MODO%
if errorlevel 1 (
  echo [X] bcdboot fallo.
  goto :dep_error
)

echo.
echo ==========================================================
echo  DESPLIEGUE TERMINADO. Retira el USB y el disco externo.
echo ==========================================================
if "%AUTO%"=="1" exit /b 0
set "R=N"
set /p R="Reiniciar ahora? S/N [N]: "
if /i "%R%"=="S" wpeutil reboot
exit /b 0

:dep_sin_letras
echo [X] No hay letras de unidad libres para las particiones.
goto :dep_error

:dep_error
echo.
echo Proceso cancelado o con errores.
call :pausa
exit /b 1


rem ==========================================================
rem  Utilidades
rem ==========================================================
:avisar_si_no_pe
if "%ENPE%"=="1" exit /b 0
rem En modo -Auto el aviso ya lo dio la interfaz grafica.
if "%AUTO%"=="1" exit /b 0
echo.
echo [AVISO] Esta opcion esta pensada para ejecutarse desde Hiren's BootCD PE
echo     y parece que estas en un Windows normal.
set "CONT="
set /p CONT="Continuar de todos modos? S/N: "
if /i "%CONT%"=="S" exit /b 0
exit /b 1

:pausa
if "%AUTO%"=="1" exit /b 0
pause
exit /b 0

:extraer_ps
rem %1 = nombre de la marca (PS1 o GUI), %2 = archivo de salida.
rem Copia el texto que hay entre esa marca y la siguiente (o el final).
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText('%SELF%'); $m='#=='+'%~1'+'==#'; $i=$t.IndexOf($m); if($i -lt 0){exit 1}; $i+=$m.Length; $j=$t.IndexOf('#'+'==',$i); if($j -lt 0){$j=$t.Length}; [IO.File]::WriteAllText('%~2',$t.Substring($i,$j-$i),(New-Object Text.UTF8Encoding $true))"
exit /b %errorlevel%


rem ==========================================================
rem  Fin de la parte CMD. Lo que sigue a las marcas es
rem  PowerShell; CMD nunca llega a ejecutarlo. No escribas la
rem  secuencia almohadilla + dos signos igual en ese codigo:
rem  es la que separa las secciones.
rem ==========================================================
#==PS1==#
<#
  Preparar y Sysprep (extraido de ImagenMaestra.cmd)
  -----------------------------------------------------------------
  Ejecutar en el EQUIPO DE REFERENCIA (ya personalizado), como
  Administrador. Valida el sistema, limpia y ejecuta Sysprep
  (/generalize /oobe /shutdown). Al terminar el equipo se APAGA:
  NO lo vuelvas a encender en Windows; arranca con Hiren's y usa
  ImagenMaestra.cmd > Capturar.

  Parametros opcionales:
    -SinCopyProfile      No copiar el perfil personalizado al usuario por defecto.
    -QuitarAppsProblema  Desinstalar automaticamente las apps de la Store que
                         bloquean Sysprep (instaladas solo para un usuario).
    -LimpiezaProfunda    DISM StartComponentCleanup /ResetBase (lento, reduce
                         el tamano de la imagen; las actualizaciones instaladas
                         ya no se podran desinstalar).
    -Confirmado          No pedir que se escriba SI antes de Sysprep (lo usa
                         la interfaz grafica, que ya lo ha confirmado).
#>
param(
    [switch]$SinCopyProfile,
    [switch]$QuitarAppsProblema,
    [switch]$LimpiezaProfunda,
    [switch]$Confirmado
)

$ErrorActionPreference = 'Stop'
function Paso($t)  { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t)    { Write-Host "   [OK] $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "   [!] $t" -ForegroundColor Yellow }
function Fallo($t) { Write-Host "   [X] $t" -ForegroundColor Red; exit 1 }

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
# Paquetes de idioma (LanguageExperiencePack) instalados solo para un usuario.
# Quitarlos SOLO es seguro si el idioma tiene ademas su paquete de idioma
# completo del sistema (LanguagePack .cab, el que instala Install-Language).
# Sin el, el idioma queda sin textos y la configuracion inicial de los equipos
# desplegados entra en bucle de reinicios, aunque se elija otro idioma.
$idiomas  = @($problema | Where-Object { $_.Name -like '*LanguageExperiencePack*' })
$problema = @($problema | Where-Object { $_.Name -notlike '*LanguageExperiencePack*' })
if ($idiomas.Count) {
    $lpInstalados = @(Get-WindowsPackage -Online -ErrorAction SilentlyContinue | Where-Object {
        $_.PackageName -like 'Microsoft-Windows-Client-LanguagePack-Package~*' -and $_.PackageState -eq 'Installed'
    } | ForEach-Object { ($_.PackageName -split '~')[3] })
}
foreach ($lxp in $idiomas) {
    $leng = $lxp.Name -replace '^Microsoft\.LanguageExperiencePack', ''
    Aviso "Paquete de idioma instalado solo para un usuario: $($lxp.Name)"
    if ($lpInstalados -contains $leng) {
        try {
            Remove-AppxPackage -Package $lxp.PackageFullName -AllUsers -ErrorAction Stop
            Ok "El idioma $leng esta instalado completo en el sistema; se quita solo su paquete por usuario."
        } catch {
            Fallo "No se pudo quitar $($lxp.Name): $($_.Exception.Message)"
        }
    } else {
        Fallo ("El idioma $leng no esta instalado completo en el sistema y quitar su paquete dejaria la imagen " +
               "en bucle. Con internet, en PowerShell como administrador: Install-Language $leng ; reinicia, " +
               "desconecta internet y vuelve a ejecutar Preparar.")
    }
}
if ($problema.Count) {
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
        Fallo "Estas apps hacen fallar Sysprep. Desinstalalas o vuelve a ejecutar marcando 'Quitar apps' (o con -QuitarAppsProblema)."
    }
} else {
    Ok "Ninguna app problematica"
}

# --- Limpieza -----------------------------------------------------
Paso "Limpiando temporales y papelera"
# Se recorre cada carpeta con -LiteralPath en vez de usar comodines: con
# $ErrorActionPreference='Stop' y rutas cortas 8.3 (C:\Users\CPEPC~1 cuando el
# usuario tiene espacios) Remove-Item "...\*" lanza un error que ignora
# -ErrorAction. Ademas se respetan los archivos ImagenMaestra_* que estan en uso.
foreach ($carpeta in @($env:TEMP, (Join-Path $env:WINDIR 'Temp'))) {
    if (-not $carpeta -or -not (Test-Path -LiteralPath $carpeta)) { continue }
    $elementos = @(Get-ChildItem -LiteralPath $carpeta -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike 'ImagenMaestra_*' })
    $fallidos = 0
    foreach ($e in $elementos) {
        try   { Remove-Item -LiteralPath $e.FullName -Recurse -Force -ErrorAction Stop }
        catch { $fallidos++ }
    }
    if ($fallidos) { Write-Host "   [i] $fallidos archivo(s) en uso se dejaron en $carpeta" -ForegroundColor DarkGray }
}
try { Clear-RecycleBin -Force -ErrorAction Stop } catch { }
Ok "Limpieza basica hecha"

if ($LimpiezaProfunda) {
    Paso "Limpieza profunda de componentes (puede tardar bastante)"
    dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
    if ($LASTEXITCODE -ne 0) { Aviso "DISM devolvio codigo $LASTEXITCODE; se continua." } else { Ok "Componentes limpiados" }
}

# --- unattend.xml (CopyProfile) -----------------------------------
$argsSysprep = @('/generalize', '/oobe', '/shutdown', '/quiet')
# CopyProfile solo es seguro desde la cuenta Administrador integrada (modo
# auditoria, SID terminado en -500). Desde una cuenta normal copia tambien su
# idioma, paquetes por usuario y estado de la Store al perfil por defecto, y la
# configuracion inicial de los equipos desplegados puede quedar en bucle.
$esAdminIntegrado = $id.User.Value -like 'S-1-5-21-*-500'
if (-not $SinCopyProfile -and -not $esAdminIntegrado) {
    Paso "CopyProfile"
    Aviso "Se OMITE CopyProfile: la cuenta actual ($env:USERNAME) no es el Administrador integrado del modo auditoria."
    Aviso "Para copiar la personalizacion, personaliza en modo auditoria (Ctrl+Shift+F3 en la primera pantalla de region)."
    $SinCopyProfile = $true
    Remove-Item $unattend -Force -ErrorAction SilentlyContinue
}
if (-not $SinCopyProfile) {
    Paso "Creando unattend.xml con CopyProfile"
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
if (-not $Confirmado) {
    $r = Read-Host "   Escribe SI para continuar"
    if ($r -ne 'SI') { Write-Host "Cancelado."; exit 0 }
}

# La marca de exito se borra antes para saber si ESTA ejecucion funciono.
$marca = Join-Path $sysprepDir 'Sysprep_succeeded.tag'
Remove-Item $marca -Force -ErrorAction SilentlyContinue

Paso "Ejecutando Sysprep"
Get-Process sysprep -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath (Join-Path $sysprepDir 'sysprep.exe') -ArgumentList $argsSysprep -Wait

if (Test-Path $marca) {
    Ok "Sysprep terminado. El equipo se va a apagar."
    Write-Host "   NO lo enciendas en Windows: arranca con Hiren's y usa Capturar." -ForegroundColor Yellow
    exit 0
}

Start-Sleep -Seconds 5
$err = Join-Path $sysprepDir 'Panther\setuperr.log'
Write-Host "`n   [X] No se encontro la marca de exito de Sysprep. Si el equipo no se apaga, Sysprep ha fallado. Ultimos errores:" -ForegroundColor Red
if (Test-Path $err) { Get-Content $err -Tail 20 }
Write-Host "Log completo: $(Join-Path $sysprepDir 'Panther\setupact.log')"
exit 1
#==GUI==#
<#
  Interfaz grafica de ImagenMaestra.cmd (extraida al ejecutarlo sin
  parametros o con "gui"). No hace el trabajo ella misma: recoge los
  datos, pide las confirmaciones y llama a
      ImagenMaestra.cmd <accion> -Auto ...
  mostrando su salida en la ventana.
#>
param([string]$Script)

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
} catch { exit 1 }
if (-not $Script -or -not (Test-Path -LiteralPath $Script)) { exit 1 }

# --- Ocultar la consola mientras se usa la ventana ----------------
$consola = [IntPtr]::Zero
try {
    Add-Type -Namespace ImagenMaestra -Name Consola -ErrorAction Stop -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
    $consola = [ImagenMaestra.Consola]::GetConsoleWindow()
} catch {}
function Mostrar-Consola([bool]$si) {
    if ($consola -ne [IntPtr]::Zero) {
        $modo = 0; if ($si) { $modo = 5 }
        [void][ImagenMaestra.Consola]::ShowWindow($consola, $modo)
    }
}

# --- Datos del entorno --------------------------------------------
$base     = Split-Path -Parent $Script
$unidad   = (Split-Path -Qualifier $Script).ToUpper()
$enPE     = Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT'
$dirImg   = Join-Path $base 'Imagenes'
$dirDrv   = Join-Path $base 'Drivers'
$archResp = Join-Path $base 'Respuesta\unattend.xml'
$dirLogs  = Join-Path $base 'Logs'
$salida   = Join-Path $env:TEMP 'ImagenMaestra_salida.txt'
try { $enc = [Console]::OutputEncoding } catch { $enc = [Text.Encoding]::Default }

$script:proc        = $null
$script:accion      = ''
$script:pos         = 0
$script:pend        = ''
$script:cancelado   = $false
$script:ultimaVacia = $false
$script:paso        = ''
$script:imagenes    = @()
$script:indices     = @()
$script:discoUsb    = $null

function TamanoTexto([double]$b) {
    if ($b -ge 1TB) { return ('{0:N1} TB' -f ($b / 1TB)) }
    if ($b -ge 1GB) { return ('{0:N1} GB' -f ($b / 1GB)) }
    return ('{0:N0} MB' -f ($b / 1MB))
}

function Detectar-Firmware {
    try {
        $v = (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction Stop).PEFirmwareType
        if ($v -eq 2) { return 'UEFI' }
        if ($v -eq 1) { return 'BIOS' }
    } catch {}
    if (Test-Path 'HKLM:\System\CurrentControlSet\Control\SecureBoot\State') { return 'UEFI' }
    return $null
}

# --- Ayudantes de interfaz ----------------------------------------
[Windows.Forms.Application]::EnableVisualStyles()
$fuente      = New-Object Drawing.Font('Segoe UI', 9)
$fuenteNegr  = New-Object Drawing.Font('Segoe UI', 9, [Drawing.FontStyle]::Bold)
$azul        = [Drawing.Color]::FromArgb(0, 84, 153)
$rojo        = [Drawing.Color]::FromArgb(196, 43, 28)
$naranja     = [Drawing.Color]::FromArgb(200, 110, 0)
$gris        = [Drawing.Color]::DimGray

function Pt([int]$x, [int]$y) { New-Object Drawing.Point($x, $y) }
function Tam([int]$w, [int]$h) { New-Object Drawing.Size($w, $h) }
function Poner($padre, $c, [int]$x, [int]$y, [int]$w = 0, [int]$h = 0) {
    $c.Location = Pt $x $y
    if ($w -gt 0) { $c.Size = Tam $w $h } else { $c.AutoSize = $true }
    $padre.Controls.Add($c)
    $c
}
function Etiqueta($padre, [string]$texto, [int]$x, [int]$y, [int]$w = 0, [int]$h = 0) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $texto
    Poner $padre $l $x $y $w $h
}
function Boton($padre, [string]$texto, [int]$x, [int]$y, [int]$w, [int]$h) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $texto
    Poner $padre $b $x $y $w $h
}
function Casilla($padre, [string]$texto, [int]$x, [int]$y, [bool]$marcada) {
    $c = New-Object Windows.Forms.CheckBox
    $c.Text = $texto
    $c.Checked = $marcada
    Poner $padre $c $x $y
}
function Lista($padre, [int]$x, [int]$y, [int]$w, [int]$h, $columnas) {
    $lv = New-Object Windows.Forms.ListView
    $lv.View = 'Details'
    $lv.FullRowSelect = $true
    $lv.MultiSelect = $false
    $lv.HideSelection = $false
    $lv.GridLines = $true
    foreach ($c in $columnas) { [void]$lv.Columns.Add($c[0], $c[1]) }
    Poner $padre $lv $x $y $w $h
}
function Informar([string]$texto, [string]$icono = 'Information') {
    [void][Windows.Forms.MessageBox]::Show($form, $texto, 'Imagen maestra', 'OK', $icono)
}
function Preguntar([string]$texto, [string]$icono = 'Question', [bool]$porDefectoNo = $false) {
    $def = 'Button1'; if ($porDefectoNo) { $def = 'Button2' }
    $r = [Windows.Forms.MessageBox]::Show($form, $texto, 'Imagen maestra', 'YesNo', $icono, $def)
    return ($r -eq 'Yes')
}

# ==================================================================
#  Ventana principal
# ==================================================================
$form = New-Object Windows.Forms.Form
$form.Text = 'Imagen maestra de Windows'
$form.ClientSize = Tam 900 720
$form.MinimumSize = Tam 916 620
$form.StartPosition = 'CenterScreen'
$form.Font = $fuente

# --- Registro (ocupa el espacio que sobra) ------------------------
$rtb = New-Object Windows.Forms.RichTextBox
$rtb.Dock = 'Fill'
$rtb.ReadOnly = $true
$rtb.BackColor = [Drawing.Color]::FromArgb(30, 30, 30)
$rtb.ForeColor = [Drawing.Color]::Gainsboro
$rtb.Font = New-Object Drawing.Font('Consolas', 9)
$rtb.BorderStyle = 'None'
$form.Controls.Add($rtb)

# --- Barra inferior: progreso, estado y botones -------------------
$pnlInf = New-Object Windows.Forms.Panel
$pnlInf.Dock = 'Bottom'
$pnlInf.Size = Tam 900 66
$barra = Poner $pnlInf (New-Object Windows.Forms.ProgressBar) 12 10 610 22
$barra.Anchor = 'Top,Left,Right'
$btnLogs = Boton $pnlInf 'Carpeta Logs' 636 8 120 26
$btnLogs.Anchor = 'Top,Right'
$btnCancelar = Boton $pnlInf 'Cancelar' 768 8 120 26
$btnCancelar.Anchor = 'Top,Right'
$btnCancelar.Enabled = $false
$lblEstado = Etiqueta $pnlInf 'Listo.' 12 40 876 20
$lblEstado.Anchor = 'Top,Left,Right'
$lblEstado.AutoEllipsis = $true
$form.Controls.Add($pnlInf)

# --- Pestanas ------------------------------------------------------
$tabs = New-Object Windows.Forms.TabControl
$tabs.Dock = 'Top'
$tabs.Size = Tam 900 300
$tpPrep = New-Object Windows.Forms.TabPage
$tpPrep.Text = '  1. Preparar y Sysprep  '
$tpCap = New-Object Windows.Forms.TabPage
$tpCap.Text = '  2. Capturar imagen  '
$tpDep = New-Object Windows.Forms.TabPage
$tpDep.Text = '  3. Desplegar imagen  '
foreach ($tp in $tpPrep, $tpCap, $tpDep) { $tp.UseVisualStyleBackColor = $true; $tabs.TabPages.Add($tp) }
$form.Controls.Add($tabs)

# --- Cabecera ------------------------------------------------------
$cab = New-Object Windows.Forms.Panel
$cab.Dock = 'Top'
$cab.Height = 62
$cab.BackColor = $azul
$t = Etiqueta $cab 'IMAGEN MAESTRA DE WINDOWS' 14 8
$t.ForeColor = [Drawing.Color]::White
$t.Font = New-Object Drawing.Font('Segoe UI', 14, [Drawing.FontStyle]::Bold)
$entorno = 'Windows'; if ($enPE) { $entorno = "WinPE / Hiren's" }
$t = Etiqueta $cab ("Entorno: $entorno        Carpeta: $base") 17 38
$t.ForeColor = [Drawing.Color]::FromArgb(205, 225, 245)
$form.Controls.Add($cab)

# ==================================================================
#  Pestana 1: Preparar y Sysprep
# ==================================================================
$t = Etiqueta $tpPrep ('Se ejecuta en el Windows del EQUIPO DE REFERENCIA ya personalizado. Comprueba dominio, ' +
    'BitLocker, reinicios pendientes y apps de la Store; limpia y ejecuta Sysprep (/generalize /oobe /shutdown).') 15 12 850 36
$chkApps   = Casilla $tpPrep 'Quitar automaticamente las apps de la Store que bloquean Sysprep' 15 56 $false
$chkLimp   = Casilla $tpPrep 'Limpieza profunda de componentes (lenta; reduce el tamano de la imagen)' 15 82 $false
$chkCopy   = Casilla $tpPrep 'Copiar el perfil personalizado al usuario por defecto (CopyProfile)' 15 108 $true
$lblPrepAv = Etiqueta $tpPrep ('Antes de empezar desconecta internet. Al terminar el equipo se APAGA: no lo enciendas en Windows; ' +
    "arranca con Hiren's y usa la pestana Capturar.") 15 145 850 36
$lblPrepAv.ForeColor = $naranja
$btnPreparar = Boton $tpPrep 'Preparar y ejecutar Sysprep' 15 195 260 40
$btnPreparar.Font = $fuenteNegr
if ($enPE) {
    foreach ($c in $chkApps, $chkLimp, $chkCopy, $btnPreparar) { $c.Enabled = $false }
    $lblPrepAv.Text = "Esta opcion se ejecuta en el Windows del equipo de referencia, no en Hiren's."
    $lblPrepAv.ForeColor = $gris
}

# ==================================================================
#  Pestana 2: Capturar
# ==================================================================
[void](Etiqueta $tpCap 'Particion con Windows que se va a capturar:' 15 10)
$lvParts = Lista $tpCap 15 30 560 120 @(@('Unidad', 60), @('Etiqueta', 150), @('Tamano', 90), @('Libre', 90), @('Sysprep', 140))
$btnActParts = Boton $tpCap 'Actualizar' 585 30 110 28
[void](Etiqueta $tpCap 'Nombre:' 15 165)
$txtNombre = Poner $tpCap (New-Object Windows.Forms.TextBox) 95 162 200 23
$txtNombre.Text = 'maestra'
[void](Etiqueta $tpCap 'Descripcion:' 315 165)
$txtDesc = Poner $tpCap (New-Object Windows.Forms.TextBox) 400 162 295 23
$txtDesc.Text = 'Imagen maestra'
$chkSwm = Casilla $tpCap 'Crear tambien copia dividida .swm (para USB de instalacion FAT32)' 15 196 $false
$lblDestino = Etiqueta $tpCap '' 15 224 680 20
$lblDestino.ForeColor = $gris
$lblDestino.AutoEllipsis = $true
$btnCapturar = Boton $tpCap 'Capturar imagen' 715 195 160 45
$btnCapturar.Font = $fuenteNegr
$t = Etiqueta $tpCap ("Arranca el equipo de referencia con Hiren's despues de Sysprep. " +
    'La captura tarda entre 20 y 60 minutos.') 715 30 160 120
$t.ForeColor = $gris

# ==================================================================
#  Pestana 3: Desplegar
# ==================================================================
[void](Etiqueta $tpDep 'Imagen:' 15 15)
$cmbImg = Poner $tpDep (New-Object Windows.Forms.ComboBox) 85 12 400 23
$cmbImg.DropDownStyle = 'DropDownList'
$btnActImg = Boton $tpDep 'Actualizar' 495 11 95 25
[void](Etiqueta $tpDep 'Indice:' 15 47)
$cmbIdx = Poner $tpDep (New-Object Windows.Forms.ComboBox) 85 44 400 23
$cmbIdx.DropDownStyle = 'DropDownList'
[void](Etiqueta $tpDep 'Firmware:' 615 15)
$cmbFw = Poner $tpDep (New-Object Windows.Forms.ComboBox) 685 12 80 23
$cmbFw.DropDownStyle = 'DropDownList'
[void]$cmbFw.Items.AddRange(@('UEFI', 'BIOS'))
$lblFw = Etiqueta $tpDep '' 772 15
$lblExtras = Etiqueta $tpDep '' 615 44 260 40
$lblExtras.ForeColor = $gris
$t = Etiqueta $tpDep 'Disco de DESTINO (se borrara por completo):' 15 82
$t.Font = $fuenteNegr
$lvDiscos = Lista $tpDep 15 102 680 135 @(@('Disco', 55), @('Modelo', 290), @('Tamano', 90), @('Interfaz', 75), @('Nota', 150))
$btnActDiscos = Boton $tpDep 'Actualizar discos' 710 102 165 28
$btnDesplegar = Boton $tpDep 'Desplegar imagen' 710 192 165 45
$btnDesplegar.Font = $fuenteNegr
$btnDesplegar.ForeColor = $rojo

# ==================================================================
#  Registro de salida
# ==================================================================
function Color-De([string]$l) {
    if ($l -match '^\s*\[X\]|^Error') { return [Drawing.Color]::Tomato }
    if ($l -match '\[OK\]') { return [Drawing.Color]::LightGreen }
    if ($l -match '\[AVISO\]|\[!\]|ATENCION') { return [Drawing.Color]::Gold }
    if ($l -match '^\s*==>|^\s*====|TERMINAD[OA]') { return [Drawing.Color]::SkyBlue }
    return [Drawing.Color]::Gainsboro
}
function Escribir([string]$l) {
    $rtb.SelectionStart = $rtb.TextLength
    $rtb.SelectionLength = 0
    $rtb.SelectionColor = Color-De $l
    $rtb.AppendText($l + "`n")
    $rtb.ScrollToCaret()
}
function Actualizar-Barra([string]$l) {
    if ($l -match '(\d{1,3})(?:[.,]\d+)?\s*%') {
        $v = [int]$matches[1]
        if ($v -le 100) {
            if ($barra.Style -ne 'Continuous') { $barra.Style = 'Continuous' }
            $barra.Value = $v
        }
    } elseif ($l -match '^\s*==>|^(Capturando|Aplicando|Particionando|Inyectando|Creando)') {
        $barra.Style = 'Marquee'
    }
}

# Lineas de barra de DISM: "[====   63.4%====      ]". No se escriben en el
# registro; solo mueven la barra de progreso y la etiqueta de estado.
function Es-Progreso([string]$l) {
    return ($l -match '^\s*\[[=\s]*\d{1,3}(?:[.,]\d+)?\s*%[=\s]*\]\s*$')
}
# Cabeceras y mensajes de DISM que no aportan nada al usuario.
function Es-Ruido([string]$l) {
    return ($l -match '^\s*(Deployment Image Servicing and Management tool|Herramienta Administraci.n y mantenimiento de im.genes de implementaci.n|Version: \d|Versi.n: \d|Image Version:|Versi.n de imagen:|The operation completed successfully\.|La operaci.n se complet. correctamente\.)')
}
function Procesar-Linea([string]$l) {
    Actualizar-Barra $l
    if (Es-Progreso $l) {
        if ($l -match '(\d{1,3})(?:[.,]\d+)?\s*%') {
            $txt = $script:paso; if (-not $txt) { $txt = 'Procesando' }
            $lblEstado.Text = "$txt  -  $($matches[1]) %"
        }
        return
    }
    if (Es-Ruido $l) { return }
    if ($l -match '^\s*==>\s*(.+)$') { $script:paso = $matches[1].Trim() }
    $vacia = ($l.Trim() -eq '')
    if ($vacia -and $script:ultimaVacia) { return }
    $script:ultimaVacia = $vacia
    Escribir $l
    if (-not $vacia) { $lblEstado.Text = $l.Trim() }
}

# Lee lo nuevo del archivo de salida. DISM reescribe la linea de
# progreso con retornos de carro; solo se guarda la ultima version.
function Leer-Salida {
    $datos = $null
    try {
        $fs = New-Object IO.FileStream($salida, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $n = [int][Math]::Min($fs.Length - $script:pos, 1048576)
            if ($n -gt 0) {
                [void]$fs.Seek($script:pos, [IO.SeekOrigin]::Begin)
                $buf = New-Object byte[] $n
                $leidos = $fs.Read($buf, 0, $n)
                $script:pos += $leidos
                $datos = $enc.GetString($buf, 0, $leidos)
            }
        } finally { $fs.Close() }
    } catch { return }
    if (-not $datos) { return }

    $partes = ($script:pend + $datos) -split "`n"
    for ($i = 0; $i -lt $partes.Count - 1; $i++) {
        $seg = @($partes[$i] -split "`r" | Where-Object { $_.Trim() -ne '' })
        $l = ''
        if ($seg.Count) { $l = $seg[-1].TrimEnd() }
        Procesar-Linea $l
    }
    $script:pend = $partes[-1]
    $seg = @($script:pend -split "`r" | Where-Object { $_.Trim() -ne '' })
    if ($seg.Count) {
        $ult = $seg[-1]
        Actualizar-Barra $ult
        if (Es-Progreso $ult) {
            if ($ult -match '(\d{1,3})(?:[.,]\d+)?\s*%') {
                $txt = $script:paso; if (-not $txt) { $txt = 'Procesando' }
                $lblEstado.Text = "$txt  -  $($matches[1]) %"
            }
        } elseif (-not (Es-Ruido $ult)) { $lblEstado.Text = $ult.Trim() }
        $fin = ''; if ($script:pend.EndsWith("`r")) { $fin = "`r" }
        $script:pend = $ult + $fin
    }
}

# ==================================================================
#  Ejecucion de acciones
# ==================================================================
function Modo-Ejecutando([bool]$si) {
    $tabs.Enabled = -not $si
    $btnCancelar.Enabled = $si
    if ($si) {
        $barra.Value = 0
        $barra.Style = 'Marquee'
        $barra.MarqueeAnimationSpeed = 30
    }
}

function Iniciar-Accion([string]$nombre, [string]$argumentos) {
    $script:accion = $nombre
    $script:cancelado = $false
    $script:pos = 0
    $script:pend = ''
    $script:ultimaVacia = $false
    $script:paso = ''
    try { [IO.File]::WriteAllText($salida, '') } catch {}
    Escribir ''
    Escribir ("==== {0}  ({1}) ====" -f $nombre, (Get-Date -Format 'HH:mm:ss'))
    $linea = '/d /s /c ""{0}" {1} -Auto <nul >"{2}" 2>&1"' -f $Script, $argumentos, $salida
    try {
        $script:proc = Start-Process -FilePath $env:ComSpec -ArgumentList $linea -WindowStyle Hidden -PassThru -ErrorAction Stop
        $null = $script:proc.Handle   # para poder leer ExitCode despues
    } catch {
        Escribir "[X] No se pudo iniciar: $($_.Exception.Message)"
        return
    }
    $lblEstado.Text = "$nombre en curso..."
    Modo-Ejecutando $true
    $timer.Start()
}

function Terminar-Accion {
    $timer.Stop()
    Leer-Salida
    $resto = @($script:pend -split "`r" | Where-Object { $_.Trim() -ne '' })
    if ($resto.Count) { Procesar-Linea $resto[-1].TrimEnd() }
    $script:pend = ''
    $codigo = $script:proc.ExitCode
    $script:proc = $null
    Modo-Ejecutando $false
    $barra.Style = 'Continuous'
    $acc = $script:accion

    if ($script:cancelado) {
        $barra.Value = 0
        Escribir '[X] Proceso cancelado por el usuario.'
        $lblEstado.Text = "$acc cancelado."
        return
    }
    if ($codigo -eq 0) {
        $barra.Value = 100
        Escribir "[OK] $acc terminado correctamente."
        $lblEstado.Text = "$acc terminado correctamente."
        switch ($acc) {
            'Preparar' {
                Informar "Sysprep terminado. El equipo se va a apagar.`n`nNO lo enciendas en Windows: arranca con Hiren's y usa Capturar."
            }
            'Capturar' {
                Cargar-Imagenes
                Informar "Imagen capturada correctamente en:`n$dirImg"
            }
            'Desplegar' {
                if (Preguntar "Despliegue terminado.`n`nRetira el USB y el disco externo antes de que arranque Windows.`n`nReiniciar ahora?") {
                    if ($enPE) { & wpeutil.exe reboot } else { & shutdown.exe /r /t 0 }
                }
            }
        }
    } else {
        if ($null -eq $codigo) { $codigo = '?' }
        $barra.Value = 0
        Escribir "[X] $acc termino con errores (codigo $codigo). Revisa los mensajes de arriba y la carpeta Logs."
        $lblEstado.Text = "$acc termino con errores (codigo $codigo)."
        Informar "$acc termino con errores (codigo $codigo).`n`nRevisa los mensajes del registro." 'Error'
    }
}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 400
$timer.Add_Tick({
    Leer-Salida
    if ($script:proc -and $script:proc.HasExited) { Terminar-Accion }
})

function Detener-Proceso {
    if ($script:proc -and -not $script:proc.HasExited) {
        $script:cancelado = $true
        & taskkill.exe /PID $script:proc.Id /T /F | Out-Null
    }
}

# ==================================================================
#  Carga de datos
# ==================================================================
function Cargar-Particiones {
    $lvParts.Items.Clear()
    $excluir = @('A:', 'B:', 'X:', $unidad)
    foreach ($d in [IO.DriveInfo]::GetDrives()) {
        $l = $d.Name.Substring(0, 2).ToUpper()
        if ($excluir -contains $l) { continue }
        if (-not (Test-Path "$l\Windows\System32\config\SYSTEM")) { continue }
        $etq = ''; $tam = ''; $libre = ''
        try {
            if ($d.IsReady) {
                $etq = $d.VolumeLabel
                $tam = TamanoTexto $d.TotalSize
                $libre = TamanoTexto $d.AvailableFreeSpace
            }
        } catch {}
        $sp = Test-Path "$l\Windows\System32\Sysprep\Sysprep_succeeded.tag"
        $it = New-Object Windows.Forms.ListViewItem($l)
        foreach ($s in $etq, $tam, $libre) { [void]$it.SubItems.Add([string]$s) }
        if ($sp) { [void]$it.SubItems.Add('Si') } else { [void]$it.SubItems.Add('NO (sin generalizar)'); $it.ForeColor = $naranja }
        $it.Tag = $sp
        [void]$lvParts.Items.Add($it)
    }
    if ($lvParts.Items.Count -ge 1) { $lvParts.Items[0].Selected = $true }
}

function Actualizar-Destino {
    $lblDestino.Text = 'Se guardara en: ' + (Join-Path $dirImg ($txtNombre.Text.Trim() + '.wim'))
}

function Cargar-Imagenes {
    $cmbImg.Items.Clear()
    $cmbIdx.Items.Clear()
    $script:imagenes = @()
    if (Test-Path $dirImg) { $script:imagenes = @(Get-ChildItem $dirImg -Filter *.wim -File | Sort-Object Name) }
    foreach ($f in $script:imagenes) { [void]$cmbImg.Items.Add(('{0}   ({1})' -f $f.Name, (TamanoTexto $f.Length))) }
    if ($script:imagenes.Count) { $cmbImg.SelectedIndex = 0 }
    Actualizar-Extras
}

function Cargar-Indices {
    $cmbIdx.Items.Clear()
    $script:indices = @()
    $i = $cmbImg.SelectedIndex
    if ($i -lt 0) { return }
    $wim = $script:imagenes[$i].FullName
    $form.Cursor = 'WaitCursor'
    try { $out = & dism.exe /English /Get-ImageInfo "/ImageFile:$wim" } catch { $out = @() }
    finally { $form.Cursor = 'Default' }
    $idx = $null
    foreach ($l in $out) {
        $l = [string]$l
        if ($l -match '^\s*Index\s*:\s*(\d+)') { $idx = $matches[1] }
        elseif ($idx -and $l -match '^\s*Name\s*:\s*(.*)$') {
            $script:indices += $idx
            [void]$cmbIdx.Items.Add(('{0} - {1}' -f $idx, $matches[1].Trim()))
            $idx = $null
        }
    }
    if (-not $script:indices.Count) { $script:indices = @('1'); [void]$cmbIdx.Items.Add('1') }
    $cmbIdx.SelectedIndex = 0
}

function Actualizar-Extras {
    $nDrv = 0
    if (Test-Path $dirDrv) { $nDrv = @(Get-ChildItem $dirDrv -Recurse -Filter *.inf -ErrorAction SilentlyContinue).Count }
    $resp = 'no'; if (Test-Path $archResp) { $resp = 'si' }
    $lblExtras.Text = "Drivers a inyectar: $nDrv archivo(s) .inf`nRespuesta\unattend.xml: $resp"
}

function Disco-Del-Script {
    try {
        $ld = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$unidad'" -ErrorAction Stop
        foreach ($p in $ld.GetRelated('Win32_DiskPartition')) {
            foreach ($dd in $p.GetRelated('Win32_DiskDrive')) { return [int]$dd.Index }
        }
    } catch {}
    return $null
}

function Discos-Diskpart {
    $f = Join-Path $env:TEMP 'ImagenMaestra_listdisk.txt'
    Set-Content -Path $f -Value 'list disk' -Encoding ASCII
    $out = & diskpart.exe /s $f
    Remove-Item $f -ErrorAction SilentlyContinue
    foreach ($l in $out) {
        if ([string]$l -match '^\s*\*?\s*\S+\s+(\d+)\s+(.+)$') {
            New-Object PSObject -Property @{ N = [int]$matches[1]; Modelo = $matches[2].Trim(); Tam = ''; Interfaz = '' }
        }
    }
}

function Cargar-Discos {
    $form.Cursor = 'WaitCursor'
    try {
        $lvDiscos.Items.Clear()
        $script:discoUsb = Disco-Del-Script
        $lista = @()
        try {
            $lista = @(Get-WmiObject Win32_DiskDrive -ErrorAction Stop | Sort-Object Index | ForEach-Object {
                New-Object PSObject -Property @{
                    N = [int]$_.Index; Modelo = [string]$_.Model
                    Tam = (TamanoTexto ([double]$_.Size)); Interfaz = [string]$_.InterfaceType
                }
            })
        } catch {}
        if (-not $lista.Count) { $lista = @(Discos-Diskpart) }
        foreach ($d in $lista) {
            $it = New-Object Windows.Forms.ListViewItem([string]$d.N)
            foreach ($s in $d.Modelo, $d.Tam, $d.Interfaz) { [void]$it.SubItems.Add([string]$s) }
            if ($null -ne $script:discoUsb -and $d.N -eq $script:discoUsb) {
                [void]$it.SubItems.Add('Contiene las imagenes')
                $it.ForeColor = $gris
            } else {
                [void]$it.SubItems.Add('')
            }
            $it.Tag = $d
            [void]$lvDiscos.Items.Add($it)
        }
    } finally { $form.Cursor = 'Default' }
}

# Dialogo que obliga a escribir BORRAR, como en el modo de texto.
function Confirmar-Borrado($d) {
    $f = New-Object Windows.Forms.Form
    $f.Text = 'Confirmar borrado del disco'
    $f.FormBorderStyle = 'FixedDialog'
    $f.StartPosition = 'CenterParent'
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.ClientSize = Tam 460 200
    $f.Font = $fuente
    $l = Etiqueta $f ("Se BORRARA TODO el contenido del disco {0}:`n    {1}   {2}`n`nEsta accion no se puede deshacer. Escribe BORRAR para continuar." -f $d.N, $d.Modelo, $d.Tam) 15 15 430 90
    $l.ForeColor = $rojo
    $l.Font = $fuenteNegr
    $txt = Poner $f (New-Object Windows.Forms.TextBox) 15 115 430 23
    $txt.CharacterCasing = 'Upper'
    $ok = Boton $f 'Borrar y desplegar' 250 155 195 30
    $ok.Enabled = $false
    $ok.DialogResult = 'OK'
    $ca = Boton $f 'Cancelar' 140 155 100 30
    $ca.DialogResult = 'Cancel'
    $f.AcceptButton = $ok
    $f.CancelButton = $ca
    $txt.Add_TextChanged({ $ok.Enabled = ($txt.Text -eq 'BORRAR') }.GetNewClosure())
    $r = $f.ShowDialog($form)
    $f.Dispose()
    return ($r -eq 'OK')
}

function Avisar-Si-No-PE {
    if ($enPE) { return $true }
    return (Preguntar ("Esta opcion esta pensada para ejecutarse desde Hiren's BootCD PE y parece " +
        "que estas en un Windows normal.`n`nContinuar de todos modos?") 'Warning' $true)
}

# ==================================================================
#  Eventos
# ==================================================================
$btnPreparar.Add_Click({
    $a = 'preparar'
    if ($chkApps.Checked) { $a += ' -QuitarAppsProblema' }
    if ($chkLimp.Checked) { $a += ' -LimpiezaProfunda' }
    if (-not $chkCopy.Checked) { $a += ' -SinCopyProfile' }
    $ok = Preguntar ("Se validara el sistema, se limpiara y se ejecutara Sysprep.`n`n" +
        "Al terminar el equipo se APAGARA. No lo vuelvas a encender en Windows: " +
        "arranca con Hiren's para capturar.`n`nContinuar?") 'Warning' $true
    if ($ok) { Iniciar-Accion 'Preparar' $a }
})

$btnActParts.Add_Click({ Cargar-Particiones })
$txtNombre.Add_TextChanged({ Actualizar-Destino })

$btnCapturar.Add_Click({
    if ($lvParts.SelectedItems.Count -eq 0) { Informar 'Elige la particion de Windows que quieres capturar.' 'Warning'; return }
    $it = $lvParts.SelectedItems[0]
    $src = $it.Text
    $nombre = $txtNombre.Text.Trim()
    if ($nombre -notmatch '^[A-Za-z0-9_.-]+$') {
        Informar 'El nombre solo puede tener letras sin tildes, numeros, guiones, puntos y guiones bajos (sin espacios).' 'Warning'
        return
    }
    if (Test-Path (Join-Path $dirImg "$nombre.wim")) { Informar "Ya existe $nombre.wim en la carpeta Imagenes. Elige otro nombre." 'Warning'; return }
    $desc = ($txtDesc.Text -replace '["&|<>^%!()]', '').Trim()
    if (-not $desc) { $desc = 'Imagen maestra' }
    if (-not (Avisar-Si-No-PE)) { return }
    if (-not $it.Tag) {
        $sigue = Preguntar ("No se encontro la marca de Sysprep en $src.`n`nPuede que NO se ejecutara Sysprep o que Windows " +
            "se arrancara despues. Una imagen sin generalizar puede dar problemas en otros equipos.`n`nContinuar de todos modos?") 'Warning' $true
        if (-not $sigue) { return }
    }
    $msg = "Origen:  $src\`nDestino: $(Join-Path $dirImg "$nombre.wim")"
    if ($chkSwm.Checked) { $msg += "`nTambien se creara la copia dividida .swm" }
    if (-not (Preguntar "$msg`n`nPuede tardar entre 20 y 60 minutos. Iniciar la captura?")) { return }
    $a = 'capturar -Origen {0} -Nombre "{1}" -Descripcion "{2}"' -f $src, $nombre, $desc
    if ($chkSwm.Checked) { $a += ' -Dividir' }
    Iniciar-Accion 'Capturar' $a
})

$btnActImg.Add_Click({ Cargar-Imagenes })
$cmbImg.Add_SelectedIndexChanged({ Cargar-Indices })
$btnActDiscos.Add_Click({ Cargar-Discos })

$btnDesplegar.Add_Click({
    if ($cmbImg.SelectedIndex -lt 0) { Informar 'No hay ninguna imagen .wim seleccionada (carpeta Imagenes).' 'Warning'; return }
    if ($lvDiscos.SelectedItems.Count -eq 0) { Informar 'Elige el disco de destino.' 'Warning'; return }
    $d = $lvDiscos.SelectedItems[0].Tag
    if ($null -ne $script:discoUsb -and $d.N -eq $script:discoUsb) {
        Informar 'Ese es el disco que contiene las imagenes. Elige otro.' 'Error'
        return
    }
    if (-not (Avisar-Si-No-PE)) { return }
    $fw = [string]$cmbFw.SelectedItem
    $idx = $script:indices[[Math]::Max(0, $cmbIdx.SelectedIndex)]
    if (-not (Confirmar-Borrado $d)) { return }
    $wim = $script:imagenes[$cmbImg.SelectedIndex].FullName
    $a = 'desplegar -Imagen "{0}" -Indice {1} -Disco {2} -Firmware {3}' -f $wim, $idx, $d.N, $fw
    Iniciar-Accion 'Desplegar' $a
})

$btnCancelar.Add_Click({
    if (-not $script:proc -or $script:proc.HasExited) { return }
    $si = Preguntar ("Cancelar el proceso en curso?`n`nSi DISM esta escribiendo la imagen o el disco, " +
        'el resultado quedara incompleto y habra que repetirlo.') 'Warning' $true
    if ($si) { Detener-Proceso }
})

$btnLogs.Add_Click({
    try {
        if (-not (Test-Path $dirLogs)) { [void](New-Item -ItemType Directory -Path $dirLogs) }
        Start-Process explorer.exe -ArgumentList "`"$dirLogs`""
    } catch { Informar "No se pudo abrir la carpeta:`n$dirLogs" 'Warning' }
})

$form.Add_FormClosing({
    param($s, $e)
    if ($script:proc -and -not $script:proc.HasExited) {
        if (Preguntar 'Hay un proceso en curso. Cancelarlo y cerrar?' 'Warning' $true) { Detener-Proceso }
        else { $e.Cancel = $true }
    }
})

$form.Add_Shown({
    $form.Cursor = 'WaitCursor'
    Escribir 'Imagen maestra de Windows'
    Escribir ("Entorno: {0}   Carpeta: {1}" -f $entorno, $base)
    Escribir ''
    Escribir 'Pasos: 1) Preparar y Sysprep en Windows  ->  2) Capturar desde Hiren''s  ->  3) Desplegar desde Hiren''s.'
    Escribir 'Aqui se mostrara la salida de cada proceso.'
    $fwDet = Detectar-Firmware
    if ($fwDet) { $cmbFw.SelectedItem = $fwDet; $lblFw.Text = '(detectado)' }
    else { $cmbFw.SelectedItem = 'UEFI'; $lblFw.Text = '(revisalo)'; $lblFw.ForeColor = $naranja }
    Actualizar-Destino
    Cargar-Particiones
    Cargar-Imagenes
    Cargar-Discos
    $form.Cursor = 'Default'
})

if ($enPE) { $tabs.SelectedTab = $tpCap } else { $tabs.SelectedTab = $tpPrep }

try {
    Mostrar-Consola $false
    [Windows.Forms.Application]::Run($form)
    exit 0
} catch {
    Mostrar-Consola $true
    Write-Host "Error en la interfaz grafica: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
