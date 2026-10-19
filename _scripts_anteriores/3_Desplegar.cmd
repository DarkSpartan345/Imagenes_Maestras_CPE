@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Despliegue de imagen maestra
rem ==========================================================
rem  3_Desplegar.cmd
rem  Ejecutar DESDE HIREN'S BOOTCD PE en el equipo de DESTINO,
rem  con esta carpeta en el disco externo. BORRA el disco elegido,
rem  lo particiona (UEFI o BIOS, autodetectado), aplica la imagen,
rem  inyecta drivers de .\Drivers y crea el arranque.
rem ==========================================================

set "BASE=%~dp0"
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
if not defined MODO (
  set /p MODO="No se pudo detectar el firmware. Escribe UEFI o BIOS: "
)
if /i not "%MODO%"=="UEFI" if /i not "%MODO%"=="BIOS" (
  echo [X] Modo no valido: %MODO%
  goto :fin_error
)
echo.
echo Firmware detectado: %MODO%

rem --- Elegir imagen ---------------------------------------
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
  goto :fin_error
)
if %N%==1 (
  set "WIM=%IMG1%"
  goto :tengo_wim
)
:elegir_wim
set "SEL="
set /p SEL="Numero de la imagen: "
set "WIM=!IMG%SEL%!"
if not defined WIM goto :elegir_wim
:tengo_wim
echo Imagen: %WIM%

dism /Get-ImageInfo /ImageFile:"%WIM%"
set "IDX=1"
set /p IDX="Indice a aplicar [1]: "

rem --- Detectar el disco que contiene este script ----------
set "LETRA=%~d0"
set "LETRA=%LETRA:~0,1%"
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
:elegir_disco
set "DISK="
set /p DISK="Numero del disco DESTINO, se borrara por completo: "
echo %DISK%| findstr /r "^[0-9][0-9]*$" >nul || goto :elegir_disco
if "%DISK%"=="%USBDISK%" (
  echo [X] Ese es el disco con las imagenes. Elige otro.
  goto :elegir_disco
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
set "CONF="
set /p CONF="Escribe BORRAR para continuar: "
if not "%CONF%"=="BORRAR" goto :fin_error

rem --- Letras libres para las particiones ------------------
set "LS="
for %%l in (S R Q P O) do if not defined LS if not exist %%l:\ set "LS=%%l"
set "LW="
for %%l in (W V U T N) do if not defined LW if not exist %%l:\ set "LW=%%l"
if not defined LS goto :sin_letras
if not defined LW goto :sin_letras

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
  goto :fin_error
)
if not exist %LW%:\ (
  echo [X] La particion de Windows %LW%: no esta disponible.
  goto :fin_error
)

rem --- Aplicar imagen --------------------------------------
echo.
echo Aplicando imagen en %LW%: ... puede tardar entre 10 y 40 minutos.
dism /Apply-Image /ImageFile:"%WIM%" /Index:%IDX% /ApplyDir:%LW%:\ /CheckIntegrity /LogPath:"%LOGS%\despliegue.log"
if errorlevel 1 (
  echo [X] Error al aplicar la imagen. Revisa %LOGS%\despliegue.log
  goto :fin_error
)

rem --- Drivers opcionales ----------------------------------
if exist "%DRVDIR%\*" (
  echo.
  echo Inyectando drivers de %DRVDIR%...
  dism /Image:%LW%:\ /Add-Driver /Driver:"%DRVDIR%" /Recurse /LogPath:"%LOGS%\drivers.log"
  if errorlevel 1 echo [!] Algunos drivers no se pudieron agregar. Revisa %LOGS%\drivers.log
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
  goto :fin_error
)

echo.
echo ==========================================================
echo  DESPLIEGUE TERMINADO. Retira el USB y el disco externo.
echo ==========================================================
set "R=N"
set /p R="Reiniciar ahora? S/N [N]: "
if /i "%R%"=="S" wpeutil reboot
exit /b 0

:sin_letras
echo [X] No hay letras de unidad libres para las particiones.
goto :fin_error

:fin_error
echo.
echo Proceso cancelado o con errores.
pause
exit /b 1
