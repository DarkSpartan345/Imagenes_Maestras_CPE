@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Captura de imagen maestra
rem ==========================================================
rem  2_Capturar.cmd
rem  Ejecutar DESDE HIREN'S BOOTCD PE, con esta carpeta copiada
rem  en el disco externo. La imagen se guarda en .\Imagenes
rem ==========================================================

set "BASE=%~dp0"
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
    if /i not "%%d:"=="%~d0" (
      set /a N+=1
      set "WIN!N!=%%d:"
      echo    [!N!] %%d:\
    )
  )
)

if %N%==0 (
  echo [X] No se encontro ninguna particion con Windows.
  goto :fin_error
)
if %N%==1 (
  set "SRC=%WIN1%"
  goto :tengo_src
)
:elegir_src
set "SEL="
set /p SEL="Numero de la particion a capturar: "
set "SRC=!WIN%SEL%!"
if not defined SRC goto :elegir_src
:tengo_src
echo.
echo Particion de origen: %SRC%

rem --- Comprobar que se ejecuto Sysprep --------------------
if not exist "%SRC%\Windows\System32\Sysprep\Sysprep_succeeded.tag" (
  echo.
  echo [!] No se encontro la marca de Sysprep en %SRC%.
  echo     Puede que NO se ejecutara Sysprep o que Windows se arrancara despues.
  echo     Una imagen sin generalizar puede dar problemas en otros equipos.
  set "CONT="
  set /p CONT="Continuar de todos modos? S/N: "
  if /i not "!CONT!"=="S" goto :fin_error
)

rem --- Nombre y descripcion --------------------------------
:pedir_nombre
echo.
set "NOMBRE=maestra"
set /p NOMBRE="Nombre de la imagen [maestra]: "
if exist "%DEST%\%NOMBRE%.wim" (
  echo [!] Ya existe %NOMBRE%.wim en %DEST%. Elige otro nombre.
  goto :pedir_nombre
)
set "DESC=Imagen maestra"
set /p DESC="Descripcion [Imagen maestra]: "

echo.
echo ----------------------------------------------------------
echo  Origen : %SRC%\
echo  Destino: %DEST%\%NOMBRE%.wim
echo  Log    : %LOGS%\captura_%NOMBRE%.log
echo ----------------------------------------------------------
set "OK="
set /p OK="Iniciar captura? S/N: "
if /i not "%OK%"=="S" goto :fin_error

echo.
echo Capturando... esto puede tardar entre 20 y 60 minutos.
dism /Capture-Image /ImageFile:"%DEST%\%NOMBRE%.wim" /CaptureDir:%SRC%\ /Name:"%NOMBRE%" /Description:"%DESC%" /Compress:max /CheckIntegrity /Verify /ScratchDir:"%SCR%" /LogPath:"%LOGS%\captura_%NOMBRE%.log"
if errorlevel 1 (
  echo.
  echo [X] DISM fallo. Revisa %LOGS%\captura_%NOMBRE%.log
  goto :fin_error
)

echo.
echo [OK] Imagen creada: %DEST%\%NOMBRE%.wim
dism /Get-ImageInfo /ImageFile:"%DEST%\%NOMBRE%.wim"

rem --- Division opcional para USB FAT32 --------------------
echo.
set "DIV=N"
set /p DIV="Crear tambien copia dividida .swm para USB de instalacion FAT32? S/N [N]: "
if /i "%DIV%"=="S" (
  if not exist "%DEST%\%NOMBRE%_swm" md "%DEST%\%NOMBRE%_swm"
  dism /Split-Image /ImageFile:"%DEST%\%NOMBRE%.wim" /SWMFile:"%DEST%\%NOMBRE%_swm\install.swm" /FileSize:3800
  if errorlevel 1 (
    echo [!] No se pudo dividir la imagen.
  ) else (
    echo [OK] Archivos .swm en %DEST%\%NOMBRE%_swm
  )
)

rmdir /s /q "%SCR%" 2>nul
echo.
echo ==========================================================
echo  CAPTURA TERMINADA
echo ==========================================================
pause
exit /b 0

:fin_error
rmdir /s /q "%SCR%" 2>nul
echo.
echo Proceso cancelado o con errores.
pause
exit /b 1
