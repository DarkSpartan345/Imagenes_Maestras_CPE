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
rem    ImagenMaestra.cmd desplegar [-Imagen ruta.wim] [-Indice 1] [-Disco 1] [-Firmware UEFI o BIOS] [-Contenidos GB]
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
rem  parte de PowerShell de "preparar", la interfaz grafica y el
rem  script que oculta la particion de contenidos educativos.
rem ==========================================================

set "SELF=%~f0"
set "BASE=%~dp0"
set "UNIDAD=%~d0"
set "ENPE=0"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\MiniNT" >nul 2>&1 && set "ENPE=1"

set "AUTO=0"
set "OPCS="
for %%v in (P_ORIGEN P_NOMBRE P_DESC P_DIVIDIR P_IMAGEN P_INDICE P_DISCO P_FIRMWARE P_CONT P_SINCONT P_SINEXTRAS) do set "%%v="

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
if /i "%~1"=="-SinContenidos" (set "P_SINCONT=1" & goto :leer_args)
if /i "%~1"=="-SinExtras" (set "P_SINEXTRAS=1" & goto :leer_args)
if /i "%~1"=="-Origen"      (set "P_ORIGEN=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Nombre"      (set "P_NOMBRE=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Descripcion" (set "P_DESC=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Imagen"      (set "P_IMAGEN=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Indice"      (set "P_INDICE=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Disco"       (set "P_DISCO=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Firmware"    (set "P_FIRMWARE=%~2" & shift & goto :leer_args)
if /i "%~1"=="-Contenidos"  (set "P_CONT=%~2" & shift & goto :leer_args)
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
set "R=N"
if exist "%BASE%Contenidos\" set "R=S"
set /p R="Crear/actualizar la particion oculta de contenidos educativos ADMINISTRACION? S/N [!R!]: "
if /i "!R!"=="S" (
  set "TG=16"
  set /p TG="Tamano en GB si hay que crearla [16]: "
  set "OPCS=!OPCS! -ParticionContenidos -TamanoContenidos !TG!"
)
set "R=S"
set /p R="Dejar SOLO la cuenta AdministradorCPE (se eliminan las demas cuentas)? S/N [S]: "
if /i "!R!"=="S" (
  set "OPCS=!OPCS! -CuentasCPE"
  set "R=S"
  set /p R="Poner contrasena a AdministradorCPE? S/N [S]: "
  if /i "!R!"=="N" set "OPCS=!OPCS! -SinClave"
  set "R=S"
  set /p R="Que los equipos desplegados arranquen sin la configuracion inicial de Windows? S/N [S]: "
  if /i "!R!"=="S" set "OPCS=!OPCS! -OmitirOOBE"
)
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
if /i "%~1"=="particiones" goto :particiones
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
echo                     -ParticionContenidos Crea/actualiza ADMINISTRACION con Contenidos\ antes de Sysprep
echo                     -TamanoContenidos 16 Tamano en GB si hay que crearla
echo                     -CuentasCPE          Deja solo la cuenta AdministradorCPE (borra las demas)
echo                     -SinClave            AdministradorCPE sin contrasena
echo                     -OmitirOOBE          Equipos desplegados sin configuracion inicial de Windows
echo    particiones    Muestra las particiones del disco de Windows: -Origen D:
echo    capturar   2   En Hiren's, equipo de referencia. Crea Imagenes\^<nombre^>.wim
echo                     -Origen D:  -Nombre x  -Descripcion "y"  -Dividir
echo                     Si existe ADMINISTRACION se anade como indice 2 (-SinContenidos para omitirla)
echo                     Recovery y datos se anaden como PARTICION_n (-SinExtras para omitirlas)
echo    desplegar  3   En Hiren's, equipo de destino. BORRA un disco y aplica una imagen.
echo                     -Imagen ruta.wim  -Indice 1  -Disco 1  -Firmware UEFI/BIOS
echo                     -Contenidos 16  Crea la particion oculta ADMINISTRACION de 16 GB
echo                                     con lo que haya en Contenidos\ (0 = no crearla)
echo.
echo    -Auto          Sin preguntas ni pausas (lo usa la interfaz grafica).
echo.
echo  Ejemplo: ImagenMaestra.cmd preparar -QuitarAppsProblema -LimpiezaProfunda
echo.
exit /b 0


rem ==========================================================
rem  PARTICIONES: revisa las particiones del disco de Windows
rem  (lo usa el boton "Revisar particiones" de la ventana)
rem ==========================================================
:particiones
setlocal
if not defined P_ORIGEN (
  echo [X] Indica la particion de Windows con -Origen D:
  exit /b 1
)
set "PRTPS=%TEMP%\ImagenMaestra_prt.ps1"
call :extraer_ps PRT "%PRTPS%"
if errorlevel 1 (
  echo [X] No se pudo extraer la parte de particiones.
  exit /b 1
)
echo Particiones del disco de %P_ORIGEN:~0,2%:
powershell -NoProfile -ExecutionPolicy Bypass -File "%PRTPS%" -Accion Revisar -Origen %P_ORIGEN:~0,2%
set "RC=%errorlevel%"
del "%PRTPS%" 2>nul
exit /b %RC%


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
set "CPEPS=%TEMP%\ImagenMaestra_cpe.ps1"
call :extraer_ps PS1 "%PS1%"
if errorlevel 1 (
  echo [X] No se pudo extraer la parte de PowerShell.
  call :pausa
  exit /b 1
)
call :extraer_ps CPE "%CPEPS%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %OPCS% %EXTRA% -OrigenContenidos "%BASE%Contenidos" -ScriptOcultar "%CPEPS%"
set "RC=%errorlevel%"
del "%PS1%" 2>nul
del "%CPEPS%" 2>nul
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
set "DP=%TEMP%\dp_captura.txt"
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

rem --- Particiones de recovery y datos ---------------------
rem  Todas las particiones del disco se conservan: las de recovery y
rem  datos se capturan como indices PARTICION_<n> del mismo .wim. Se
rem  revisan antes de empezar para no capturar a medias.
set "PRTPS=%TEMP%\ImagenMaestra_prt.ps1"
if defined P_SINEXTRAS goto :cap_sin_revisar
call :extraer_ps PRT "%PRTPS%"
if errorlevel 1 (
  echo [X] No se pudo extraer la parte de particiones.
  goto :cap_error
)
echo.
echo Particiones del disco de %SRC%:
powershell -NoProfile -ExecutionPolicy Bypass -File "%PRTPS%" -Accion Revisar -Origen %SRC%
if errorlevel 1 goto :cap_error
:cap_sin_revisar

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
if defined P_SINCONT (echo  Contenidos: no se capturan) else (echo  Contenidos: si existe ADMINISTRACION se anade como indice 2)
if defined P_SINEXTRAS (echo  Recovery y datos: no se capturan) else (echo  Recovery y datos: se anaden como indices PARTICION_n)
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

rem --- Particion de contenidos educativos ------------------
if defined P_SINCONT goto :cap_info
call :cap_contenidos
if errorlevel 1 goto :cap_error
:cap_info

rem --- Particiones de recovery y datos ---------------------
if defined P_SINEXTRAS goto :cap_info2
powershell -NoProfile -ExecutionPolicy Bypass -File "%PRTPS%" -Accion Capturar -Origen %SRC% -Imagen "%DEST%\%NOMBRE%.wim" -Scratch "%SCR%" -Logs "%LOGS%" -NombreImagen "%NOMBRE%"
if errorlevel 1 (
  echo [X] No se pudieron capturar todas las particiones. Revisa los mensajes y la carpeta Logs.
  goto :cap_error
)
:cap_info2
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

rem --- Anadir ADMINISTRACION como otro indice del .wim -------
rem  Se busca por el marcador en las unidades con letra; si no
rem  tiene letra (lo normal, esta oculta) se busca por la etiqueta
rem  en diskpart, que la muestra recortada a 11 letras.
:cap_contenidos
set "CL="
set "CMONT="
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
  if not defined CL if /i not "%%d:"=="%UNIDAD%" if exist "%%d:\.cpe-contenidos-id" set "CL=%%d"
)
if defined CL goto :cap_cont_tengo
set "CVOL="
> "%DP%" echo list volume
for /f "tokens=1-4" %%a in ('diskpart /s "%DP%"') do (
  if /i "%%c"=="ADMINISTRAC" set "CVOL=%%b"
  if /i "%%d"=="ADMINISTRAC" set "CVOL=%%b"
)
if not defined CVOL (
  echo.
  echo [i] No se encontro la particion ADMINISTRACION: solo se captura Windows.
  exit /b 0
)
for %%l in (K L M J I H) do if not defined CL if not exist %%l:\ set "CL=%%l"
if not defined CL (
  echo [X] No hay letra libre para montar ADMINISTRACION.
  exit /b 1
)
> "%DP%" (
  echo select volume %CVOL%
  echo assign letter=%CL%
)
diskpart /s "%DP%" >nul
set "CMONT=1"
if not exist "%CL%:\.cpe-contenidos-id" (
  echo [AVISO] El volumen ADMINISTRACION no tiene el marcador .cpe-contenidos-id.
)
:cap_cont_tengo
echo.
echo Capturando la particion de contenidos educativos %CL%: como indice ADMINISTRACION...
dism /Append-Image /ImageFile:"%DEST%\%NOMBRE%.wim" /CaptureDir:%CL%:\ /Name:"ADMINISTRACION" /Description:"Contenidos educativos CPE" /CheckIntegrity /Verify /ScratchDir:"%SCR%" /LogPath:"%LOGS%\captura_%NOMBRE%_contenidos.log"
set "RCC=%errorlevel%"
if defined CMONT (
  > "%DP%" (
    echo select volume %CL%
    echo remove letter=%CL%
  )
  diskpart /s "%DP%" >nul
)
if not "%RCC%"=="0" (
  echo [X] DISM fallo al capturar los contenidos. Revisa %LOGS%\captura_%NOMBRE%_contenidos.log
  exit /b 1
)
echo [OK] Contenidos anadidos a %NOMBRE%.wim como indice ADMINISTRACION.
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
rem Particion de contenidos educativos (ver ParticionDisco / ConsolidadoCPE).
rem La estructura y el marcador son los que valida 00-InstaladorCPE.
set "CONTDIR=%BASE%Contenidos"
set "CONTGB_DEF=16"
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
rem Indice con la particion de contenidos (lo anade "capturar").
set "CIDX="
set "_I="
set "_N="
set "HAYEXTRA="
for /f "tokens=1,2,*" %%a in ('dism /English /Get-ImageInfo /ImageFile:"%WIM%"') do (
  if /i "%%a"=="Index" set "_I=%%c"
  if /i "%%a"=="Name" if "%%c"=="ADMINISTRACION" set "CIDX=!_I!"
  if /i "%%a"=="Name" set "_N=%%c"
  if /i "%%a"=="Name" if /i "!_N:~0,10!"=="PARTICION_" set "HAYEXTRA=1"
)
if defined CIDX echo [i] La imagen incluye la particion de contenidos ADMINISTRACION, indice %CIDX%.
if defined HAYEXTRA echo [i] La imagen incluye particiones de recovery o datos del equipo de referencia.
set "IDX=1"
if defined P_INDICE (set "IDX=%P_INDICE%") else (set /p IDX="Indice de Windows a aplicar [1]: ")
if "%IDX%"=="%CIDX%" (
  echo [X] El indice %IDX% es la particion de contenidos, no Windows.
  goto :dep_error
)

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

rem --- Particion de contenidos educativos (opcional) -------
set "CGB=0"
if defined P_CONT (
  set "CGB=%P_CONT%"
) else if not "%AUTO%"=="1" (
  echo.
  set "R=S"
  if defined CIDX (
    echo [i] Se aplicaran los contenidos que trae la imagen, indice !CIDX!.
  ) else if exist "!CONTDIR!\" (
    echo [i] La imagen no trae contenidos; se copiarian desde !CONTDIR!
  ) else (
    echo [i] La imagen no trae contenidos y no existe !CONTDIR!: la particion se crearia vacia.
    set "R=N"
  )
  set /p R="Crear la particion oculta de contenidos educativos ADMINISTRACION? S/N [!R!]: "
  if /i "!R!"=="S" (
    set "CGB=%CONTGB_DEF%"
    set /p CGB="Tamano de la particion de contenidos en GB [%CONTGB_DEF%]: "
  )
)
echo %CGB%| findstr /r "^0$ ^[1-9][0-9]*$" >nul || (
  echo [X] Tamano de la particion de contenidos no valido: %CGB%
  goto :dep_error
)
set "CMB=0"
if not "%CGB%"=="0" set /a "CMB=CGB*1024"
set "DISKMB=0"
for /f %%s in ('powershell -NoProfile -Command "foreach($d in Get-WmiObject Win32_DiskDrive){if($d.Index -eq %DISK%){[int64]($d.Size/1MB)}}" 2^>nul') do set "DISKMB=%%s"
if "%DISKMB%"=="0" echo [AVISO] No se pudo leer el tamano del disco %DISK%; solo se mostraran los requisitos.

rem --- Tamano minimo y particiones de recovery/datos --------
rem  Calcula cuanto disco necesita la imagen (Windows + margen,
rem  ADMINISTRACION y particiones extra) y si el disco elegido alcanza.
rem  Si el disco es pequeno, reduce las particiones de datos hasta lo
rem  que ocupan (+20 %); si ni asi cabe, se detiene sin tocar nada.
set "PLANDIR=%TEMP%\ImagenMaestra_plan"
set "PRTPS=%TEMP%\ImagenMaestra_prt.ps1"
set "NEXTRA=0"
set "EXTRAMB=0"
if exist "%PLANDIR%\plan.cmd" del "%PLANDIR%\plan.cmd"
call :extraer_ps PRT "%PRTPS%"
if errorlevel 1 goto :dep_plan_fallo
echo.
echo Comprobando si la imagen cabe en el disco %DISK%...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PRTPS%" -Accion Plan -Imagen "%WIM%" -IndiceWin %IDX% -Firmware %MODO% -DiscoMB %DISKMB% -ContMB %CMB% -DirPlan "%PLANDIR%"
set "RCP=%errorlevel%"
if "%RCP%"=="2" (
  echo [X] El disco %DISK% es demasiado pequeno para esta imagen. No se toco nada.
  goto :dep_error
)
if not "%RCP%"=="0" goto :dep_plan_fallo
if not exist "%PLANDIR%\plan.cmd" goto :dep_plan_fallo
call "%PLANDIR%\plan.cmd"
goto :dep_plan_ok
:dep_plan_fallo
if defined HAYEXTRA (
  echo [X] No se pudo preparar el plan de particiones; sin el se perderian las de recovery y datos.
  goto :dep_error
)
echo [AVISO] No se pudo comprobar el tamano del disco; se continua sin esa comprobacion.
:dep_plan_ok

echo.
echo ***********************************************************
echo  ATENCION: se BORRARA TODO el contenido del disco %DISK%.
if not "%CGB%"=="0" echo  Se creara ademas la particion oculta ADMINISTRACION de %CGB% GB.
if not "%NEXTRA%"=="0" echo  Se recrearan %NEXTRA% particiones de recovery o datos de la imagen.
if "%PLANRED%"=="1" echo  Las particiones de datos se reduciran a lo que ocupan, sin perder archivos.
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
set "LC="
if not "%CGB%"=="0" (
  for %%l in (K L M J I H) do if not defined LC if not exist %%l:\ set "LC=%%l"
  if not defined LC goto :dep_sin_letras
)

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
  )
)
rem ADMINISTRACION y las particiones extra salen del final de la de
rem Windows: ADMINISTRACION sigue siendo la 4 (UEFI) o la 3 (BIOS).
set /a "SHRINKMB=CMB+EXTRAMB"
if not "%SHRINKMB%"=="0" (
  >> "%DP%" echo shrink desired=%SHRINKMB% minimum=%SHRINKMB%
)
if not "%CGB%"=="0" (
  >> "%DP%" (
    echo create partition primary size=%CMB%
    echo format quick fs=ntfs label="ADMINISTRACION"
    echo assign letter=%LC%
  )
)
if not "%NEXTRA%"=="0" type "%PLANDIR%\extras_dp.txt" >> "%DP%"
>> "%DP%" echo exit
diskpart /s "%DP%"
if errorlevel 1 (
  echo [X] Error al particionar el disco.
  goto :dep_error
)
if not exist %LW%:\ (
  echo [X] La particion de Windows %LW%: no esta disponible.
  goto :dep_error
)
if not "%CGB%"=="0" if not exist %LC%:\ (
  echo [X] La particion de contenidos %LC%: no esta disponible.
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

rem --- Script que oculta la particion en el primer arranque --
rem  Windows asigna letra a las particiones nuevas al instalarse;
rem  SetupComplete.cmd (se ejecuta como SYSTEM) se la quita.
if not "%CGB%"=="0" (
  echo.
  echo Instalando el script que oculta ADMINISTRACION al terminar la instalacion...
  if not exist "%LW%:\Windows\Setup\Scripts" md "%LW%:\Windows\Setup\Scripts"
  call :extraer_ps CPE "%LW%:\Windows\Setup\Scripts\CPE-OcultarContenidos.ps1"
  if errorlevel 1 (
    echo [X] No se pudo extraer el script CPE-OcultarContenidos.ps1.
    goto :dep_error
  )
  rem Si la imagen ya lo traia (preparar con contenidos) no se duplica.
  findstr /i /c:"CPE-OcultarContenidos" "%LW%:\Windows\Setup\Scripts\SetupComplete.cmd" >nul 2>&1 || (
    >> "%LW%:\Windows\Setup\Scripts\SetupComplete.cmd" echo powershell -NoProfile -ExecutionPolicy Bypass -File "%%WINDIR%%\Setup\Scripts\CPE-OcultarContenidos.ps1"
  )
)

rem --- Arranque --------------------------------------------
echo.
echo Creando archivos de arranque...
bcdboot %LW%:\Windows /s %LS%: /f %MODO%
if errorlevel 1 (
  echo [X] bcdboot fallo.
  goto :dep_error
)

rem --- Contenidos educativos -------------------------------
if not "%CGB%"=="0" (
  call :dep_contenidos
  if errorlevel 1 goto :dep_error
)

rem --- Particiones de recovery y datos ---------------------
if not "%NEXTRA%"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PRTPS%" -Accion Aplicar -Imagen "%WIM%" -DirPlan "%PLANDIR%" -LetraWin %LW% -Logs "%LOGS%"
  if errorlevel 1 (
    echo [X] No se pudieron restaurar todas las particiones de recovery y datos.
    goto :dep_error
  )
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

rem --- Llenar, proteger y ocultar ADMINISTRACION ------------
rem  Permisos por SID (validos en Hiren's y en el Windows final):
rem  SYSTEM y Administradores control total; Usuarios (cualquier
rem  cuenta estandar) solo lectura y ejecucion. Sin reglas DENY.
:dep_contenidos
echo.
echo Preparando la particion de contenidos educativos en %LC%: ...
if not defined CIDX goto :dep_cont_permisos
echo Aplicando los contenidos educativos de la imagen, indice %CIDX% ...
dism /Apply-Image /ImageFile:"%WIM%" /Index:%CIDX% /ApplyDir:%LC%:\ /CheckIntegrity /LogPath:"%LOGS%\despliegue_contenidos.log"
if errorlevel 1 (
  echo [X] Error al aplicar los contenidos. Revisa %LOGS%\despliegue_contenidos.log
  exit /b 1
)
:dep_cont_permisos
icacls %LC%:\ /inheritance:r >nul
icacls %LC%:\ /remove:g *S-1-5-11 *S-1-3-0 *S-1-1-0 >nul
icacls %LC%:\ /grant:r *S-1-5-18:(OI)(CI)F *S-1-5-32-544:(OI)(CI)F *S-1-5-32-545:(OI)(CI)RX
if errorlevel 1 (
  echo [X] No se pudieron aplicar los permisos a %LC%:\
  exit /b 1
)
icacls %LC%:\ /setowner *S-1-5-32-544 >nul
for %%c in (Videos Aplicaciones Material) do md "%LC%:\CONTENIDOS\%%c" 2>nul
if not exist "%LC%:\.cpe-contenidos-id" <nul set /p "=CPE-CONTENIDOS-V1" > "%LC%:\.cpe-contenidos-id"

if defined CIDX goto :dep_cont_ocultar
if not exist "%CONTDIR%\" (
  echo [AVISO] No existe !CONTDIR!: se crea solo la estructura vacia.
  goto :dep_cont_ocultar
)
echo Copiando contenidos y aplicaciones educativas desde %CONTDIR% ...
if not exist "%SystemRoot%\System32\robocopy.exe" goto :dep_cont_xcopy
robocopy "%CONTDIR%" "%LC%:\CONTENIDOS" /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NP /NDL /NJH
if errorlevel 8 (
  echo [X] Robocopy fallo al copiar los contenidos.
  exit /b 1
)
goto :dep_cont_ocultar
:dep_cont_xcopy
xcopy "%CONTDIR%\*" "%LC%:\CONTENIDOS\" /E /I /H /Y
rem 1 = no habia archivos que copiar; no es un error.
if errorlevel 2 (
  echo [X] Xcopy fallo al copiar los contenidos.
  exit /b 1
)

:dep_cont_ocultar
for %%c in (Videos Aplicaciones Material) do if not exist "%LC%:\CONTENIDOS\%%c\" (
  echo [X] Falta la carpeta CONTENIDOS\%%c en la particion de contenidos.
  exit /b 1
)
echo [OK] Contenidos copiados en ADMINISTRACION.
rem Sin letra; en GPT ademas con el atributo "sin letra de unidad"
rem para que Windows no se la asigne al arrancar.
> "%DP%" (
  echo select volume %LC%
  if /i "%MODO%"=="UEFI" echo gpt attributes=0x8000000000000000
  echo remove letter=%LC%
  echo exit
)
diskpart /s "%DP%" >nul
if errorlevel 1 (
  echo [AVISO] No se pudo quitar la letra %LC%: ahora; se quitara en el primer arranque.
) else (
  echo [OK] Particion ADMINISTRACION oculta, sin letra de unidad.
)
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
    -ParticionContenidos Antes de Sysprep crea (o actualiza, si ya existe) la
                         particion oculta ADMINISTRACION reduciendo C:, copia
                         los contenidos y aplicaciones educativas y la protege,
                         para que quede en la imagen capturada.
    -TamanoContenidos N  Tamano en GB de la particion nueva (16 por defecto).
    -OrigenContenidos    Carpeta con Videos, Aplicaciones y Material (la pasa
                         ImagenMaestra.cmd: <carpeta del script>\Contenidos).
    -ScriptOcultar       Script CPE-OcultarContenidos.ps1 extraido por el .cmd.
    -CuentasCPE          Antes de Sysprep deja SOLO la cuenta AdministradorCPE
                         (administradora). Si la cuenta con la que se
                         personalizo el equipo es local, se renombra y conserva
                         su perfil; si no, se crea. Las demas cuentas se
                         eliminan con su perfil (las integradas de Windows
                         siguen deshabilitadas). La contrasena se pide en
                         consola o la deja cifrada la interfaz grafica en
                         %TEMP%\ImagenMaestra_cpe_clave.txt.
    -SinClave            AdministradorCPE queda sin contrasena.
    -OmitirOOBE          Los equipos desplegados no muestran la configuracion
                         inicial: arrancan directo al inicio de sesion con esas
                         cuentas, con el idioma, teclado y zona horaria de este
                         equipo. Requiere -CuentasCPE.
#>
param(
    [switch]$SinCopyProfile,
    [switch]$QuitarAppsProblema,
    [switch]$LimpiezaProfunda,
    [switch]$Confirmado,
    [switch]$ParticionContenidos,
    [int]$TamanoContenidos = 16,
    [string]$OrigenContenidos,
    [string]$ScriptOcultar,
    [switch]$CuentasCPE,
    [switch]$SinClave,
    [switch]$OmitirOOBE
)

$ErrorActionPreference = 'Stop'
function Paso($t)  { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t)    { Write-Host "   [OK] $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "   [!] $t" -ForegroundColor Yellow }
function Fallo($t) { Write-Host "   [X] $t" -ForegroundColor Red; exit 1 }

$sysprepDir = Join-Path $env:WINDIR 'System32\Sysprep'
$unattend   = Join-Path $sysprepDir 'unattend.xml'

# Contrasena de AdministradorCPE que deja la interfaz grafica (cifrada con
# DPAPI para este usuario). Se lee y se borra enseguida, pase lo que pase.
$archivoClave = Join-Path $env:TEMP 'ImagenMaestra_cpe_clave.txt'
$claveCPE = $null
if (Test-Path -LiteralPath $archivoClave) {
    try { if ($CuentasCPE) { $claveCPE = Get-Content -LiteralPath $archivoClave | ConvertTo-SecureString } }
    catch { $claveCPE = $null }
    finally { Remove-Item -LiteralPath $archivoClave -Force -ErrorAction SilentlyContinue }
}
if ($OmitirOOBE -and -not $CuentasCPE) {
    Write-Host "   [X] -OmitirOOBE necesita -CuentasCPE: sin cuentas preparadas los equipos no tendrian con que iniciar sesion." -ForegroundColor Red
    exit 1
}

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

# --- Particion de contenidos educativos (ADMINISTRACION) ----------
# Se hace antes de Sysprep para que la particion forme parte de la imagen:
# la captura la anade como un indice mas del .wim y el despliegue la recrea.
# Permisos por SID (no dependen de las cuentas, que cambian de SID al
# generalizar): SYSTEM y Administradores control total; Usuarios (cualquier
# cuenta estandar) solo lectura y ejecucion. Sin reglas DENY.
if ($ParticionContenidos) {
    Paso "Particion de contenidos educativos (ADMINISTRACION)"
    $etiqueta = 'ADMINISTRACION'
    # C: debe quedar con espacio libre suficiente tras reducirla (no un
    # tamano fijo), para poder preparar tambien equipos de disco pequeno.
    $minLibreCGB = 10
    $vols = @(Get-Volume | Where-Object { $_.FileSystemLabel -eq $etiqueta })
    if ($vols.Count -gt 1) { Fallo "Hay mas de un volumen con la etiqueta $etiqueta. Revisalo en Administracion de discos." }

    if ($vols.Count -eq 0) {
        if ($TamanoContenidos -lt 1) { Fallo "Tamano de la particion de contenidos no valido: $TamanoContenidos GB." }
        $cPart = Get-Partition -DriveLetter $env:SystemDrive.Substring(0, 1)
        $disco = Get-Disk -Number $cPart.DiskNumber
        $pedido = [int64]$TamanoContenidos * 1GB
        $nuevoC = [int64]($cPart.Size - $pedido)
        $sop = Get-PartitionSupportedSize -DiskNumber $cPart.DiskNumber -PartitionNumber $cPart.PartitionNumber
        $usadoC = [int64]((Get-Volume -DriveLetter $env:SystemDrive.Substring(0, 1)) | ForEach-Object { $_.Size - $_.SizeRemaining })
        if (($nuevoC - $usadoC) -lt [int64]$minLibreCGB * 1GB) {
            Fallo ("Reducir {0} GB dejaria {1} con menos de {2} GB libres (usados {3:N1} GB). Libera espacio o elige un tamano menor." -f $TamanoContenidos, $env:SystemDrive, $minLibreCGB, ($usadoC / 1GB))
        }
        if ($nuevoC -lt $sop.SizeMin) {
            Fallo ("Windows solo permite reducir {0} {1:N1} GB y se necesitan {2} GB. Libera espacio, desactiva la hibernacion (powercfg /h off) y vuelve a intentarlo." -f $env:SystemDrive, (($cPart.Size - $sop.SizeMin) / 1GB), $TamanoContenidos)
        }
        if ($disco.LargestFreeExtent -gt 1GB) {
            Fallo "El disco ya tiene espacio sin asignar ($([math]::Round($disco.LargestFreeExtent / 1GB, 1)) GB). Revisalo antes de crear la particion."
        }
        Write-Host ("   Se reducira {0} de {1:N1} GB a {2:N1} GB y se creara {3} de {4} GB." -f $env:SystemDrive, ($cPart.Size / 1GB), ($nuevoC / 1GB), $etiqueta, $TamanoContenidos) -ForegroundColor Yellow
        if (-not $Confirmado) {
            $r = Read-Host "   Escribe CREAR para continuar"
            if ($r -ne 'CREAR') { Write-Host "Cancelado."; exit 0 }
        }
        Resize-Partition -DiskNumber $cPart.DiskNumber -PartitionNumber $cPart.PartitionNumber -Size $nuevoC
        Ok "$env:SystemDrive reducida"
        $nueva = New-Partition -DiskNumber $cPart.DiskNumber -UseMaximumSize
        Format-Volume -Partition $nueva -FileSystem NTFS -NewFileSystemLabel $etiqueta -Confirm:$false -Force | Out-Null
        Ok "Particion $etiqueta creada (disco $($nueva.DiskNumber), particion $($nueva.PartitionNumber))"
        $vols = @(Get-Volume | Where-Object { $_.FileSystemLabel -eq $etiqueta })
    } else {
        Ok "Ya existe $etiqueta; se actualizan su contenido y permisos"
    }

    $p = $vols[0] | Get-Partition
    $montada = $false
    if ($p.DriveLetter) {
        $letra = [string]$p.DriveLetter
    } else {
        $letra = $null
        foreach ($l in 'K','L','M','J','I','H','P','Q','R') {
            if (-not (Test-Path "$($l):\")) { $letra = $l; break }
        }
        if (-not $letra) { Fallo "No hay una letra libre para montar $etiqueta." }
        Add-PartitionAccessPath -DiskNumber $p.DiskNumber -PartitionNumber $p.PartitionNumber -AccessPath "$($letra):\"
        $montada = $true
    }
    $raiz = "$($letra):\"
    try {
        & icacls.exe $raiz /inheritance:r | Out-Null
        & icacls.exe $raiz /remove:g '*S-1-5-11' '*S-1-3-0' '*S-1-1-0' | Out-Null
        & icacls.exe $raiz /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
        if ($LASTEXITCODE -ne 0) { Fallo "No se pudieron aplicar los permisos a $raiz" }
        & icacls.exe $raiz /setowner '*S-1-5-32-544' | Out-Null
        foreach ($c in 'Videos','Aplicaciones','Material') {
            New-Item -ItemType Directory -Force -Path (Join-Path $raiz "CONTENIDOS\$c") | Out-Null
        }
        Set-Content -LiteralPath (Join-Path $raiz '.cpe-contenidos-id') -Value 'CPE-CONTENIDOS-V1' -Encoding ASCII -NoNewline
        Ok "Permisos, estructura CONTENIDOS\ y marcador listos"

        if ($OrigenContenidos -and (Test-Path -LiteralPath $OrigenContenidos)) {
            Write-Host "   Copiando contenidos y aplicaciones desde $OrigenContenidos ..."
            & robocopy.exe $OrigenContenidos (Join-Path $raiz 'CONTENIDOS') /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NP /NDL /NJH
            if ($LASTEXITCODE -ge 8) { Fallo "Robocopy fallo (codigo $LASTEXITCODE) al copiar los contenidos." }
            Ok "Contenidos copiados"
        } else {
            Aviso "No se encontro la carpeta de contenidos ($OrigenContenidos); la particion queda con lo que ya tenia."
        }
    } finally {
        if ($montada) { Remove-PartitionAccessPath -DiskNumber $p.DiskNumber -PartitionNumber $p.PartitionNumber -AccessPath $raiz -ErrorAction SilentlyContinue }
    }
    if ($p.DriveLetter) {
        Remove-PartitionAccessPath -DiskNumber $p.DiskNumber -PartitionNumber $p.PartitionNumber -AccessPath $raiz
    }
    try {
        Set-Partition -DiskNumber $p.DiskNumber -PartitionNumber $p.PartitionNumber -NoDefaultDriveLetter $true -ErrorAction Stop
    } catch {
        Aviso "No se pudo marcar la particion como 'sin letra' (normal en discos MBR); la ocultara SetupComplete."
    }
    Ok "$etiqueta oculta, sin letra de unidad"

    # Queda dentro de la imagen: al instalarse en cada equipo, SetupComplete
    # quita la letra que Windows haya asignado a la particion.
    if ($ScriptOcultar -and (Test-Path -LiteralPath $ScriptOcultar)) {
        $dirSc = Join-Path $env:WINDIR 'Setup\Scripts'
        New-Item -ItemType Directory -Force -Path $dirSc | Out-Null
        Copy-Item -LiteralPath $ScriptOcultar -Destination (Join-Path $dirSc 'CPE-OcultarContenidos.ps1') -Force
        $sc = Join-Path $dirSc 'SetupComplete.cmd'
        if (-not ((Test-Path $sc) -and (Select-String -LiteralPath $sc -SimpleMatch 'CPE-OcultarContenidos' -Quiet))) {
            Add-Content -LiteralPath $sc -Encoding ASCII -Value 'powershell -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\CPE-OcultarContenidos.ps1"'
        }
        Ok "SetupComplete.cmd ocultara $etiqueta en cada equipo desplegado"
    } else {
        Aviso "No se recibio CPE-OcultarContenidos.ps1; en los equipos desplegados la particion podria verse con letra."
    }
}

# --- Cuenta CPE: solo AdministradorCPE ------------------------------
# Se hace antes de Sysprep para que la cuenta viaje en la imagen. Sysprep
# conserva las cuentas locales, sus grupos y contrasenas, pero les cambia
# el SID; por eso los permisos de ADMINISTRACION usan grupos (SID fijo).
# Quedan solo AdministradorCPE y las cuentas integradas de Windows
# (Administrador, Invitado, DefaultAccount, WDAGUtilityAccount), que
# siguen deshabilitadas. Las demas se eliminan con su perfil.
if ($CuentasCPE) {
    Paso "Cuenta CPE: solo AdministradorCPE"
    $nomAdmin = 'AdministradorCPE'
    $grpAdmin = (Get-LocalGroup | Where-Object { $_.SID.Value -eq 'S-1-5-32-544' }).Name
    # Se compara por SID: ADSI guarda a los miembros como
    # WinNT://WORKGROUP/EQUIPO/usuario y una comparacion por ruta falla.
    function EsMiembro([string]$grupo, [string]$usuario) {
        $cu = Get-LocalUser -Name $usuario -ErrorAction SilentlyContinue
        if (-not $cu) { return $false }
        $g = [ADSI]"WinNT://$env:COMPUTERNAME/$grupo,group"
        foreach ($m in @($g.Invoke('Members'))) {
            try {
                $bytes = $m.GetType().InvokeMember('objectSid', 'GetProperty', $null, $m, $null)
                if ((New-Object Security.Principal.SecurityIdentifier($bytes, 0)).Value -eq $cu.SID.Value) { return $true }
            } catch {}
        }
        return $false
    }
    function PonerEnGrupo([string]$grupo, [string]$usuario) {
        if (EsMiembro $grupo $usuario) { return }
        try { Add-LocalGroupMember -Group $grupo -Member $usuario -ErrorAction Stop }
        catch { Aviso "Add-LocalGroupMember ($usuario en $grupo): $($_.Exception.Message)" }
    }
    function TextoPlano($seguro) {
        $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
    }
    # Cuentas integradas de Windows: Administrador, Invitado, DefaultAccount, WDAGUtilityAccount.
    function EsIntegrada($u) { return ($u.SID.Value -match '-(500|501|503|504)$') }

    $adm = Get-LocalUser -Name $nomAdmin -ErrorAction SilentlyContinue
    $actual = Get-LocalUser | Where-Object { $_.SID.Value -eq $id.User.Value }

    # Contrasena: la elige el usuario. -SinClave deja AdministradorCPE sin contrasena.
    if ($SinClave) {
        $claveCPE = $null
    } elseif (-not $claveCPE -and -not $Confirmado) {
        $txt = "   Contrasena para $nomAdmin"
        if ($adm) { $txt += ' (Enter para dejar la actual)' }
        $c1 = Read-Host $txt -AsSecureString
        if ($c1.Length -gt 0) {
            $c2 = Read-Host '   Repite la contrasena' -AsSecureString
            if ((TextoPlano $c1) -cne (TextoPlano $c2)) { Fallo "Las contrasenas no coinciden. No se modifico ninguna cuenta." }
            $claveCPE = $c1
        }
    }
    if (-not $adm -and -not $claveCPE -and -not $SinClave) {
        Fallo "Falta la contrasena para $nomAdmin (o elige 'Sin contrasena'). No se modifico ninguna cuenta."
    }

    # AdministradorCPE: si la cuenta con la que se personalizo el equipo es
    # local y no integrada, se renombra y conserva su perfil y personalizacion.
    # Si no (modo auditoria con el Administrador integrado, o cuenta Microsoft),
    # se crea una cuenta nueva.
    if (-not $adm) {
        if ($actual -and -not (EsIntegrada $actual) -and "$($actual.PrincipalSource)" -eq 'Local') {
            $antes = $actual.Name
            Rename-LocalUser -SID $actual.SID -NewName $nomAdmin
            Ok "La cuenta $antes (con la que se personalizo el equipo) pasa a llamarse $nomAdmin"
        } else {
            if ($claveCPE) { New-LocalUser -Name $nomAdmin -Password $claveCPE -Description 'Cuenta administrativa CPE' | Out-Null }
            else { New-LocalUser -Name $nomAdmin -NoPassword -Description 'Cuenta administrativa CPE' | Out-Null }
            Ok "Cuenta $nomAdmin creada"
        }
    }
    if ($SinClave) {
        $u = [ADSI]"WinNT://$env:COMPUTERNAME/$nomAdmin,user"
        $u.SetPassword('')
        $u.PasswordExpired = 0
        $u.SetInfo()
        Ok "$nomAdmin queda SIN contrasena"
    } elseif ($claveCPE) {
        Set-LocalUser -Name $nomAdmin -Password $claveCPE
        Ok "Contrasena de $nomAdmin establecida"
    } else {
        Ok "$nomAdmin conserva su contrasena actual"
    }
    Set-LocalUser -Name $nomAdmin -PasswordNeverExpires $true
    Enable-LocalUser -Name $nomAdmin
    PonerEnGrupo $grpAdmin $nomAdmin
    $claveCPE = $null
    if (-not (EsMiembro $grpAdmin $nomAdmin)) { Fallo "$nomAdmin no quedo en el grupo $grpAdmin." }

    # Eliminar las demas cuentas y sus perfiles. La cuenta con la sesion
    # abierta (o un perfil en uso) no se puede borrar ahora: queda anotada y
    # la borra el script de primer arranque en cada equipo desplegado.
    $pendientes = @()
    $sobran = @(Get-LocalUser | Where-Object { $_.Name -ne $nomAdmin -and -not (EsIntegrada $_) })
    foreach ($u in $sobran) {
        $perfil = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { $_.SID -eq $u.SID.Value }
        if ($u.SID.Value -eq $id.User.Value -or ($perfil -and $perfil.Loaded)) {
            $pendientes += $u.Name
            Aviso "La cuenta $($u.Name) esta en uso; se eliminara en el primer arranque de cada equipo."
            continue
        }
        try {
            if ($perfil) { $perfil | Remove-CimInstance -ErrorAction Stop }
            Remove-LocalUser -SID $u.SID -ErrorAction Stop
            Ok "Cuenta $($u.Name) eliminada junto con su perfil"
        } catch {
            $pendientes += $u.Name
            Aviso "No se pudo eliminar $($u.Name) ahora ($($_.Exception.Message)); se eliminara en el primer arranque."
        }
    }
    $dirSc = Join-Path $env:WINDIR 'Setup\Scripts'
    $listaPend = Join-Path $dirSc 'CPE-EliminarCuentas.txt'
    if ($pendientes.Count) {
        if (-not ($ScriptOcultar -and (Test-Path -LiteralPath $ScriptOcultar))) {
            Fallo "Hay cuentas que solo se pueden eliminar en el primer arranque, pero no se recibio el script de primer arranque."
        }
        New-Item -ItemType Directory -Force -Path $dirSc | Out-Null
        Copy-Item -LiteralPath $ScriptOcultar -Destination (Join-Path $dirSc 'CPE-OcultarContenidos.ps1') -Force
        $sc = Join-Path $dirSc 'SetupComplete.cmd'
        if (-not ((Test-Path $sc) -and (Select-String -LiteralPath $sc -SimpleMatch 'CPE-OcultarContenidos' -Quiet))) {
            Add-Content -LiteralPath $sc -Encoding ASCII -Value 'powershell -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\CPE-OcultarContenidos.ps1"'
        }
        $pendientes | Set-Content -LiteralPath $listaPend -Encoding UTF8
        Ok "Cuentas a eliminar en el primer arranque: $($pendientes -join ', ')"
    } else {
        Remove-Item -LiteralPath $listaPend -Force -ErrorAction SilentlyContinue
    }
    $restantes = @(Get-LocalUser | Where-Object { $_.Enabled -and -not (EsIntegrada $_) } | ForEach-Object { $_.Name })
    Ok "Cuentas habilitadas ahora: $($restantes -join ', ')"
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
}
Remove-Item $unattend -Force -ErrorAction SilentlyContinue

$comp = 'processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"'
$pases = @()
if (-not $SinCopyProfile) {
    $pases += @"
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" $comp>
      <CopyProfile>true</CopyProfile>
    </component>
  </settings>
"@
}
# Sin configuracion inicial: los equipos desplegados arrancan directo al
# inicio de sesion con las cuentas CPE. Idioma, teclado y zona horaria se
# copian de este equipo para que la OOBE no tenga nada que preguntar.
if ($OmitirOOBE) {
    $uiCult = Get-WinUILanguageOverride
    if (-not $uiCult) { $uiCult = [Globalization.CultureInfo]::InstalledUICulture }
    $teclado = @((Get-WinUserLanguageList)[0].InputMethodTips)[0]
    if (-not $teclado) { $teclado = $uiCult.Name }
    $sysLoc = (Get-WinSystemLocale).Name
    $usrLoc = (Get-Culture).Name
    $zona   = (Get-TimeZone).Id
    $pases += @"
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" $comp>
      <InputLocale>$teclado</InputLocale>
      <SystemLocale>$sysLoc</SystemLocale>
      <UILanguage>$($uiCult.Name)</UILanguage>
      <UserLocale>$usrLoc</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" $comp>
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <TimeZone>$zona</TimeZone>
    </component>
  </settings>
"@
}
if ($pases.Count) {
    Paso "Creando unattend.xml"
    ('<?xml version="1.0" encoding="utf-8"?>' + "`r`n" +
     '<unattend xmlns="urn:schemas-microsoft-com:unattend">' + "`r`n" +
     ($pases -join "`r`n") + "`r`n" + '</unattend>') | Set-Content -Path $unattend -Encoding UTF8
    $argsSysprep += "/unattend:$unattend"
    if (-not $SinCopyProfile) { Ok "CopyProfile activado" }
    if ($OmitirOOBE) { Ok "Configuracion inicial omitida en los equipos desplegados (idioma $($uiCult.Name), teclado $teclado, zona $zona)" }
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
$dirCont  = Join-Path $base 'Contenidos'
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
$script:bytesCont   = 0
$script:infoCarpeta = ''
$script:idxCont     = $null
$script:bytesImgCont = 0

function TamanoTexto([double]$b) {
    if ($b -ge 1TB) { return ('{0:N1} TB' -f ($b / 1TB)) }
    if ($b -ge 1GB) { return ('{0:N1} GB' -f ($b / 1GB)) }
    return ('{0:N0} MB' -f ($b / 1MB))
}

# Funciones de la seccion de particiones (PRT): el mismo calculo de disco
# minimo y la misma lectura de la imagen que usa el despliegue.
$script:prtOk = $false
try {
    $txtScript = [IO.File]::ReadAllText($Script)
    $marca = '#' + '==' + 'PRT' + '==' + '#'
    $ini = $txtScript.IndexOf($marca)
    if ($ini -ge 0) {
        $ini += $marca.Length
        $fin = $txtScript.IndexOf('#' + '==', $ini); if ($fin -lt 0) { $fin = $txtScript.Length }
        $prtGui = Join-Path $env:TEMP 'ImagenMaestra_prt_gui.ps1'
        [IO.File]::WriteAllText($prtGui, $txtScript.Substring($ini, $fin - $ini), (New-Object Text.UTF8Encoding $true))
        . $prtGui -Accion Funciones
        $script:prtOk = $true
    }
} catch { $script:prtOk = $false }
$script:infoImagen = $null

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
$tabs.Size = Tam 900 345
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
$chkPrepCont = Casilla $tpPrep 'Crear/actualizar particion oculta de contenidos ADMINISTRACION:' 15 134 $false
$numPrepCont = Poner $tpPrep (New-Object Windows.Forms.NumericUpDown) 500 133 60 23
$numPrepCont.Minimum = 1
$numPrepCont.Maximum = 2000
$numPrepCont.Value = 16
$numPrepCont.Enabled = $false
[void](Etiqueta $tpPrep 'GB' 564 136)
$lblPrepCont = Etiqueta $tpPrep '' 600 128 270 30
$lblPrepCont.ForeColor = $gris
$lblPrepCont.AutoEllipsis = $true
$chkCuentas = Casilla $tpPrep 'Dejar SOLO la cuenta AdministradorCPE. Contrasena:' 15 162 $true
$txtClave1 = Poner $tpPrep (New-Object Windows.Forms.TextBox) 410 160 120 23
$txtClave1.UseSystemPasswordChar = $true
[void](Etiqueta $tpPrep 'Repetir:' 540 163)
$txtClave2 = Poner $tpPrep (New-Object Windows.Forms.TextBox) 595 160 120 23
$txtClave2.UseSystemPasswordChar = $true
$chkSinClave = Casilla $tpPrep 'Sin contrasena' 728 161 $false
$lblClave = Etiqueta $tpPrep '' 520 190 355 20
$lblClave.ForeColor = $gris
$lblClave.AutoEllipsis = $true
$chkOobe = Casilla $tpPrep 'Equipos desplegados sin configuracion inicial (directo al inicio de sesion)' 15 188 $true
$lblPrepAv = Etiqueta $tpPrep ('Antes de empezar desconecta internet. Al terminar el equipo se APAGA: no lo enciendas en Windows; ' +
    "arranca con Hiren's y usa la pestana Capturar. La particion y las cuentas quedan dentro de la imagen.") 15 216 850 36
$lblPrepAv.ForeColor = $naranja
$btnPreparar = Boton $tpPrep 'Preparar y ejecutar Sysprep' 15 256 260 40
$btnPreparar.Font = $fuenteNegr
if ($enPE) {
    foreach ($c in $chkApps, $chkLimp, $chkCopy, $chkPrepCont, $numPrepCont, $chkCuentas, $txtClave1, $txtClave2, $chkSinClave, $chkOobe, $btnPreparar) { $c.Enabled = $false }
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
$chkCapCont = Casilla $tpCap 'Anadir la particion ADMINISTRACION a la imagen (indice 2)' 15 250 $true
$lblCapCont = Etiqueta $tpCap '' 420 252 455 20
$lblCapCont.ForeColor = $gris
$chkCapExtras = Casilla $tpCap 'Anadir las particiones de recovery y datos del disco (PARTICION_n)' 15 276 $true
$btnRevPart = Boton $tpCap 'Revisar particiones' 715 272 160 26
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
$chkCont = Casilla $tpDep 'Particion oculta de contenidos educativos ADMINISTRACION:' 15 250 $false
$numCont = Poner $tpDep (New-Object Windows.Forms.NumericUpDown) 440 249 60 23
$numCont.Minimum = 1
$numCont.Maximum = 2000
$numCont.Value = 16
$numCont.Enabled = $false
[void](Etiqueta $tpDep 'GB' 504 252)
$lblCont = Etiqueta $tpDep '' 545 252 330 40
$lblReq = Etiqueta $tpDep '' 15 298 860 20
$lblReq.AutoEllipsis = $true
$lblCont.ForeColor = $gris
$lblCont.AutoEllipsis = $true

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
    } elseif ($l -match '^\s*==>|^(Capturando|Aplicando|Particionando|Inyectando|Creando|Preparando|Copiando)') {
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
    $v = Volumen-Contenidos
    if ($v) {
        $lblCapCont.Text = "Detectada: $(TamanoTexto ([double]$v.Capacity)), $(TamanoTexto ([double]($v.Capacity - $v.FreeSpace))) usados"
        $chkCapCont.Checked = $true
    } else {
        $lblCapCont.Text = 'No hay particion ADMINISTRACION en este equipo.'
        $chkCapCont.Checked = $false
    }
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
    # El indice ADMINISTRACION (lo anade "capturar") no es un Windows:
    # no se ofrece en la lista; se aplica en su propia particion.
    $script:idxCont = $null
    $script:bytesImgCont = 0
    $idx = $null; $nom = $null
    foreach ($l in $out) {
        $l = [string]$l
        if ($l -match '^\s*Index\s*:\s*(\d+)') { $idx = $matches[1]; $nom = $null }
        elseif ($idx -and $l -match '^\s*Name\s*:\s*(.*)$') {
            $nom = $matches[1].Trim()
            if ($nom -eq 'ADMINISTRACION') { $script:idxCont = $idx }
            elseif ($nom -match '^PARTICION_\d+$') { }
            else {
                $script:indices += $idx
                [void]$cmbIdx.Items.Add(('{0} - {1}' -f $idx, $nom))
            }
        }
        elseif ($idx -and $nom -eq 'ADMINISTRACION' -and $l -match '^\s*Size\s*:\s*([\d,.]+)') {
            $script:bytesImgCont = [double]($matches[1] -replace '[,.]', '')
        }
    }
    if (-not $script:indices.Count) { $script:indices = @('1'); [void]$cmbIdx.Items.Add('1') }
    $script:infoImagen = $null
    if ($script:prtOk) { try { $script:infoImagen = Info-De-Salida $out } catch {} }
    $cmbIdx.SelectedIndex = 0
    Actualizar-Contenidos
    Actualizar-Requisitos
}

# Pestana 3: disco minimo para la imagen elegida y si cada disco alcanza
# (mismo calculo que el despliegue). Las particiones de datos se pueden
# reducir hasta lo que ocupan (+20 %) para caber en discos mas pequenos.
function Actualizar-Requisitos {
    if (-not $script:prtOk -or -not $script:infoImagen -or -not $script:indices.Count) { $lblReq.Text = ''; return }
    $idxWin = [int]$script:indices[[Math]::Max(0, $cmbIdx.SelectedIndex)]
    $fw = [string]$cmbFw.SelectedItem; if (-not $fw) { $fw = 'UEFI' }
    $contMB = 0; if ($chkCont.Checked) { $contMB = [long]$numCont.Value * 1024 }
    $p = Calcular-Plan $script:infoImagen $idxWin $fw 0 $contMB
    $txt = "Disco minimo: $(Texto-GB $p.ReqOrigMB)"
    if ($p.ReqMinMB -lt $p.ReqOrigMB) { $txt += " ($(Texto-GB $p.ReqMinMB) reduciendo particiones de datos)" }
    $txt += " - Windows: minimo $(Texto-GB $p.WinMinMB)"
    if ($p.Extras.Count) { $txt += "; particiones de recovery/datos: $($p.Extras.Count)" }
    $lblReq.Text = $txt
    foreach ($it in $lvDiscos.Items) {
        $d = $it.Tag
        if ($null -ne $script:discoUsb -and $d.N -eq $script:discoUsb) { continue }
        if (-not $d.Bytes) { $it.SubItems[4].Text = ''; continue }
        $pd = Calcular-Plan $script:infoImagen $idxWin $fw ([long]($d.Bytes / 1MB)) $contMB
        if (-not $pd.Cabe) { $it.SubItems[4].Text = "PEQUENO: faltan $(Texto-GB ($pd.ReqMinMB - $pd.DiscoMB))"; $it.ForeColor = $rojo }
        elseif ($pd.Reducido) { $it.SubItems[4].Text = 'Cabe reduciendo datos'; $it.ForeColor = $naranja }
        else { $it.SubItems[4].Text = 'Cabe'; $it.ForeColor = $lvDiscos.ForeColor }
    }
}

# Volumen ADMINISTRACION de este equipo (con o sin letra), o $null.
function Volumen-Contenidos {
    try { return @(Get-WmiObject Win32_Volume -Filter "Label='ADMINISTRACION'" -ErrorAction Stop)[0] } catch { return $null }
}

# Pestana 3: de donde saldran los contenidos al desplegar.
function Actualizar-Contenidos {
    $necesario = 0
    if ($script:idxCont) {
        $lblCont.Text = "La imagen trae ADMINISTRACION (indice $($script:idxCont), $(TamanoTexto $script:bytesImgCont))"
        $necesario = $script:bytesImgCont
        $chkCont.Checked = $true
    } elseif (Test-Path $dirCont) {
        $lblCont.Text = "La imagen no trae contenidos; se copiara $($script:infoCarpeta)"
        $necesario = $script:bytesCont
        $chkCont.Checked = $true
    } else {
        $lblCont.Text = 'La imagen no trae contenidos y no existe Contenidos\'
        $chkCont.Checked = $false
    }
    $gb = [Math]::Ceiling($necesario * 1.2 / 1GB)
    if ($gb -gt $numCont.Value -and $gb -le $numCont.Maximum) { $numCont.Value = $gb }
}

function Actualizar-Extras {
    $nDrv = 0
    if (Test-Path $dirDrv) { $nDrv = @(Get-ChildItem $dirDrv -Recurse -Filter *.inf -ErrorAction SilentlyContinue).Count }
    $resp = 'no'; if (Test-Path $archResp) { $resp = 'si' }
    $lblExtras.Text = "Drivers a inyectar: $nDrv archivo(s) .inf`nRespuesta\unattend.xml: $resp"

    $script:bytesCont = 0
    $script:infoCarpeta = ''
    if (Test-Path $dirCont) {
        $arch = @(Get-ChildItem $dirCont -Recurse -File -Force -ErrorAction SilentlyContinue)
        $bytes = ($arch | Measure-Object Length -Sum).Sum
        if (-not $bytes) { $bytes = 0 }
        $nApps = @(Get-ChildItem (Join-Path $dirCont 'Aplicaciones') -Recurse -File -ErrorAction SilentlyContinue).Count
        $script:bytesCont = [double]$bytes
        $script:infoCarpeta = "Contenidos\: $($arch.Count) archivo(s), $(TamanoTexto $bytes); aplicaciones: $nApps"
    }
    Actualizar-Contenidos

    # Pestana 1: particion de este equipo y carpeta de origen.
    if (-not $enPE) {
        $v = Volumen-Contenidos
        $txt = 'ADMINISTRACION no existe: se creara.'
        if ($v) { $txt = "ADMINISTRACION ya existe ($(TamanoTexto ([double]$v.Capacity))): se actualizara." }
        if ($script:infoCarpeta) { $txt += "`n" + $script:infoCarpeta } else { $txt += "`nNo existe la carpeta Contenidos\" }
        $lblPrepCont.Text = $txt
        $chkPrepCont.Checked = [bool]($v -or $script:infoCarpeta)
        $gb = [Math]::Ceiling($script:bytesCont * 1.2 / 1GB)
        if ($gb -gt $numPrepCont.Value -and $gb -le $numPrepCont.Maximum) { $numPrepCont.Value = $gb }
    }
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
            New-Object PSObject -Property @{ N = [int]$matches[1]; Modelo = $matches[2].Trim(); Tam = ''; Interfaz = ''; Bytes = [double]0 }
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
                    Bytes = [double]$_.Size
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
        Actualizar-Requisitos
    } finally { $form.Cursor = 'Default' }
}

# Dialogo que obliga a escribir BORRAR, como en el modo de texto.
function Confirmar-Borrado($d, [int]$contGB = 0, [string]$nota = '') {
    $f = New-Object Windows.Forms.Form
    $f.Text = 'Confirmar borrado del disco'
    $f.FormBorderStyle = 'FixedDialog'
    $f.StartPosition = 'CenterParent'
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.ClientSize = Tam 460 265
    $f.Font = $fuente
    $extra = ''
    if ($contGB -gt 0) { $extra = "`nSe creara la particion oculta ADMINISTRACION de $contGB GB." }
    $extra += $nota
    $l = Etiqueta $f ("Se BORRARA TODO el contenido del disco {0}:`n    {1}   {2}{3}`n`nEsta accion no se puede deshacer. Escribe BORRAR para continuar." -f $d.N, $d.Modelo, $d.Tam, $extra) 15 15 430 150
    $l.ForeColor = $rojo
    $l.Font = $fuenteNegr
    $txt = Poner $f (New-Object Windows.Forms.TextBox) 15 175 430 23
    $txt.CharacterCasing = 'Upper'
    $ok = Boton $f 'Borrar y desplegar' 250 218 195 30
    $ok.Enabled = $false
    $ok.DialogResult = 'OK'
    $ca = Boton $f 'Cancelar' 140 218 100 30
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
    $extra = ''
    if ($chkPrepCont.Checked) {
        $a += " -ParticionContenidos -TamanoContenidos $([int]$numPrepCont.Value)"
        if (Volumen-Contenidos) {
            $extra = "Se actualizara la particion ADMINISTRACION con la carpeta Contenidos\.`n`n"
        } else {
            $extra = "Se REDUCIRA C: en $([int]$numPrepCont.Value) GB para crear la particion oculta ADMINISTRACION con la carpeta Contenidos\.`n`n"
        }
    }
    if ($chkCuentas.Checked) {
        $admCPE = Get-LocalUser -Name 'AdministradorCPE' -ErrorAction SilentlyContinue
        if (-not $chkSinClave.Checked) {
            if ($txtClave1.Text -cne $txtClave2.Text) { Informar 'Las contrasenas de AdministradorCPE no coinciden.' 'Warning'; return }
            if (-not $txtClave1.Text -and -not $admCPE) { Informar 'Escribe la contrasena para AdministradorCPE o marca "Sin contrasena".' 'Warning'; return }
        }
        $a += ' -CuentasCPE'
        if ($chkSinClave.Checked) { $a += ' -SinClave' }
        if ($chkOobe.Checked) { $a += ' -OmitirOOBE' }
        # Mismo criterio que Preparar: se conservan AdministradorCPE y las integradas;
        # si AdministradorCPE no existe, la cuenta local actual se renombra.
        $sidActual = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $renombrar = $null
        if (-not $admCPE) {
            $renombrar = Get-LocalUser | Where-Object { $_.SID.Value -eq $sidActual -and $_.SID.Value -notmatch '-(500|501|503|504)$' -and "$($_.PrincipalSource)" -eq 'Local' }
        }
        $borrar = @(Get-LocalUser | Where-Object {
            $_.Name -ne 'AdministradorCPE' -and $_.SID.Value -notmatch '-(500|501|503|504)$' -and
            -not ($renombrar -and $_.SID.Value -eq $renombrar.SID.Value) } | ForEach-Object { $_.Name })
        if ($renombrar) { $extra += "La cuenta $($renombrar.Name) pasara a llamarse AdministradorCPE (conserva su perfil).`n" }
        elseif (-not $admCPE) { $extra += "Se creara la cuenta AdministradorCPE.`n" }
        if ($chkSinClave.Checked) { $extra += "AdministradorCPE quedara SIN contrasena.`n" }
        if ($borrar.Count) { $extra += "Se ELIMINARAN estas cuentas con sus perfiles y archivos: $($borrar -join ', ').`n" }
        else { $extra += "No hay otras cuentas que eliminar.`n" }
        if ($chkOobe.Checked) { $extra += "Los equipos desplegados arrancaran directo al inicio de sesion, sin configuracion inicial.`n" }
        $extra += "`n"
    }
    $ok = Preguntar ($extra + "Se validara el sistema, se limpiara y se ejecutara Sysprep.`n`n" +
        "Al terminar el equipo se APAGARA. No lo vuelvas a encender en Windows: " +
        "arranca con Hiren's para capturar.`n`nContinuar?") 'Warning' $true
    if (-not $ok) { return }
    # La contrasena viaja cifrada (DPAPI, solo este usuario); el script la borra al leerla.
    $archivoClave = Join-Path $env:TEMP 'ImagenMaestra_cpe_clave.txt'
    Remove-Item -LiteralPath $archivoClave -Force -ErrorAction SilentlyContinue
    if ($chkCuentas.Checked -and $txtClave1.Text) {
        try {
            ConvertTo-SecureString $txtClave1.Text -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -LiteralPath $archivoClave -Encoding ASCII
        } catch { Informar "No se pudo preparar la contrasena: $($_.Exception.Message)" 'Error'; return }
    }
    $txtClave1.Text = ''; $txtClave2.Text = ''
    Iniciar-Accion 'Preparar' $a
})

$chkCuentas.Add_CheckedChanged({
    foreach ($c in $chkSinClave, $chkOobe) { $c.Enabled = $chkCuentas.Checked -and -not $enPE }
    foreach ($c in $txtClave1, $txtClave2) { $c.Enabled = $chkCuentas.Checked -and -not $chkSinClave.Checked -and -not $enPE }
    if (-not $chkCuentas.Checked) { $chkOobe.Checked = $false }
})
$chkSinClave.Add_CheckedChanged({
    foreach ($c in $txtClave1, $txtClave2) { $c.Enabled = $chkCuentas.Checked -and -not $chkSinClave.Checked -and -not $enPE }
    if ($chkSinClave.Checked) { $txtClave1.Text = ''; $txtClave2.Text = '' }
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
    if ($chkCapCont.Checked) { $msg += "`nSi existe ADMINISTRACION se anadira como indice 2" }
    if ($chkCapExtras.Checked) { $msg += "`nLas particiones de recovery y datos se anadiran como PARTICION_n" }
    if ($chkSwm.Checked) { $msg += "`nTambien se creara la copia dividida .swm" }
    if (-not (Preguntar "$msg`n`nPuede tardar entre 20 y 60 minutos. Iniciar la captura?")) { return }
    $a = 'capturar -Origen {0} -Nombre "{1}" -Descripcion "{2}"' -f $src, $nombre, $desc
    if ($chkSwm.Checked) { $a += ' -Dividir' }
    if (-not $chkCapCont.Checked) { $a += ' -SinContenidos' }
    if (-not $chkCapExtras.Checked) { $a += ' -SinExtras' }
    Iniciar-Accion 'Capturar' $a
})

$btnActImg.Add_Click({ Cargar-Imagenes })
$cmbImg.Add_SelectedIndexChanged({ Cargar-Indices })
$btnActDiscos.Add_Click({ Cargar-Discos })
$chkCont.Add_CheckedChanged({ $numCont.Enabled = $chkCont.Checked; Actualizar-Requisitos })
$numCont.Add_ValueChanged({ Actualizar-Requisitos })
$cmbIdx.Add_SelectedIndexChanged({ Actualizar-Requisitos })
$cmbFw.Add_SelectedIndexChanged({ Actualizar-Requisitos })
$btnRevPart.Add_Click({
    if ($lvParts.SelectedItems.Count -eq 0) { Informar 'Elige la particion de Windows.' 'Warning'; return }
    Iniciar-Accion 'Revisar particiones' ('particiones -Origen {0}' -f $lvParts.SelectedItems[0].Text)
})
$chkPrepCont.Add_CheckedChanged({ $numPrepCont.Enabled = $chkPrepCont.Checked -and -not $enPE })

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
    $contGB = 0
    if ($chkCont.Checked) {
        $contGB = [int]$numCont.Value
        $necesario = $script:bytesCont
        if ($script:idxCont) { $necesario = $script:bytesImgCont }
        if ($necesario -gt ($contGB * 1GB * 0.95)) {
            Informar ("Los contenidos ocupan {0} y no caben en {1} GB. Aumenta el tamano de la particion." -f (TamanoTexto $necesario), $contGB) 'Warning'
            return
        }

        if (-not $script:idxCont -and -not (Test-Path $dirCont)) {
            if (-not (Preguntar "No existe la carpeta Contenidos\.`n`nLa particion ADMINISTRACION se creara vacia (solo la estructura). Continuar?" 'Warning' $true)) { return }
        }
    }
    $nota = ''
    if ($script:prtOk -and $script:infoImagen -and $d.Bytes -gt 0) {
        $pd = Calcular-Plan $script:infoImagen ([int]$idx) $fw ([long]($d.Bytes / 1MB)) ([long]$contGB * 1024)
        if (-not $pd.Cabe) {
            Informar ("La imagen no cabe en el disco {0} ({1}).`n`nNecesita al menos {2} (Windows minimo {3})." -f $d.N, $d.Tam, (Texto-GB $pd.ReqMinMB), (Texto-GB $pd.WinMinMB)) 'Warning'
            return
        }
        if ($pd.Extras.Count) { $nota += "`nSe recrearan $($pd.Extras.Count) particiones de recovery/datos de la imagen." }
        if ($pd.Reducido) { $nota += "`nLas particiones de datos se reduciran a lo que ocupan (sin perder archivos)." }
    }
    if (-not (Confirmar-Borrado $d $contGB $nota)) { return }
    $wim = $script:imagenes[$cmbImg.SelectedIndex].FullName
    $a = 'desplegar -Imagen "{0}" -Indice {1} -Disco {2} -Firmware {3} -Contenidos {4}' -f $wim, $idx, $d.N, $fw, $contGB
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
    if (-not $enPE) {
        try {
            if (Get-LocalUser -Name 'AdministradorCPE' -ErrorAction Stop) { $lblClave.Text = 'AdministradorCPE ya existe: contrasena vacia = no cambiarla' }
        } catch { $lblClave.Text = 'AdministradorCPE se creara o renombrara' }
    }
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
#==CPE==#
<#
  CPE-OcultarContenidos.ps1 (extraido de ImagenMaestra.cmd). Queda en
  Windows\Setup\Scripts y lo ejecuta SetupComplete.cmd como SYSTEM al
  terminar la instalacion en cada equipo desplegado. Hace dos cosas:

  1. Elimina, con su perfil, las cuentas que Preparar no pudo borrar en el
     equipo de referencia porque estaban en uso (CPE-EliminarCuentas.txt).
  2. Quita la letra de unidad que Windows asigna a ADMINISTRACION al
     instalarse, para que no aparezca en el Explorador. No toca archivos
     ni permisos.
  Registro: C:\Windows\Logs\CPE-Contenidos.log
#>
$ErrorActionPreference = 'Stop'
$etiqueta = 'ADMINISTRACION'
$log = Join-Path $env:WINDIR 'Logs\CPE-Contenidos.log'
$lista = Join-Path $PSScriptRoot 'CPE-EliminarCuentas.txt'
$codigo = 0
function Log([string]$t) {
    try { Add-Content -LiteralPath $log -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $t) } catch {}
}

# 1. Cuentas pendientes de eliminar (nunca AdministradorCPE ni las integradas).
if (Test-Path -LiteralPath $lista) {
    foreach ($nombre in @(Get-Content -LiteralPath $lista -Encoding UTF8 | Where-Object { $_.Trim() })) {
        $nombre = $nombre.Trim()
        try {
            $u = Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue
            if (-not $u) { Log "Cuenta ${nombre}: ya no existe."; continue }
            if ($nombre -eq 'AdministradorCPE' -or $u.SID.Value -match '-(500|501|503|504)$') { Log "Cuenta ${nombre}: protegida, no se elimina."; continue }
            $perfil = Get-CimInstance Win32_UserProfile | Where-Object { $_.SID -eq $u.SID.Value }
            if ($perfil) { $perfil | Remove-CimInstance }
            Remove-LocalUser -SID $u.SID
            Log "Cuenta $nombre eliminada junto con su perfil."
        } catch { Log "Error al eliminar la cuenta ${nombre}: $($_.Exception.Message)"; $codigo = 1 }
    }
    Remove-Item -LiteralPath $lista -Force -ErrorAction SilentlyContinue
}

# 2. Ocultar ADMINISTRACION.
try {
    Log "Buscando el volumen $etiqueta."
    $vols = @(Get-Volume | Where-Object { $_.FileSystemLabel -eq $etiqueta })
    if (-not $vols.Count) { Log "No se encontro el volumen $etiqueta." }
    foreach ($v in $vols) {
        $p = $v | Get-Partition
        if (-not $p.DriveLetter) { Log "Disco $($p.DiskNumber), particion $($p.PartitionNumber): ya estaba sin letra."; continue }
        $letra = $p.DriveLetter
        Remove-PartitionAccessPath -DiskNumber $p.DiskNumber -PartitionNumber $p.PartitionNumber -AccessPath "$($letra):\"
        Log "Disco $($p.DiskNumber), particion $($p.PartitionNumber): quitada la letra $($letra):."
    }
} catch {
    Log "Error: $($_.Exception.Message)"
    $codigo = 1
}
exit $codigo
#==PRT==#
<#
  Particiones adicionales del equipo de referencia (recovery, datos de
  programas externos...). Lo usan ImagenMaestra.cmd y la interfaz grafica.

    -Accion Revisar   -Origen D:   lista las particiones del disco de Windows y
                                   que se hara con cada una (no cambia nada)
    -Accion Capturar  -Origen D: -Imagen x.wim -Scratch dir -Logs dir -NombreImagen n
                                   anade cada particion extra como un indice
                                   PARTICION_<n> del .wim
    -Accion Plan      -Imagen x.wim -IndiceWin 1 -Firmware UEFI -DiscoMB n -ContMB n -DirPlan dir
                                   calcula el disco minimo, comprueba si el disco
                                   destino alcanza y genera el particionado
    -Accion Aplicar   -Imagen x.wim -DirPlan dir -LetraWin W -Logs dir
                                   aplica las particiones extra y registra WinRE
    -Accion Funciones solo define las funciones (la interfaz carga el archivo)

  La descripcion de cada indice PARTICION_<n> guarda como recrearla:
    CPEPART;n=;tipo=;attr=;mb=;usado=;fs=;etiqueta=;recovery=
#>
param(
    [ValidateSet('Revisar', 'Capturar', 'Plan', 'Aplicar', 'Funciones')]
    [string]$Accion = 'Funciones',
    [string]$Origen,
    [string]$Imagen,
    [string]$Scratch,
    [string]$Logs,
    [string]$NombreImagen = 'imagen',
    [int]$IndiceWin = 1,
    [string]$Firmware = 'UEFI',
    [long]$DiscoMB = 0,
    [long]$ContMB = 0,
    [string]$DirPlan,
    [string]$LetraWin = 'W'
)

$GuidEfi      = 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
$GuidMsr      = 'e3c9e316-0b5c-4db8-817d-f92df00215ae'
$GuidDatos    = 'ebd0a0a2-b9e5-4433-87c0-68b6b72699c7'
$GuidRecovery = 'de94bba4-06d1-4d40-a16a-bfd50179d6ac'
# Windows necesita sitio ademas de lo que ocupa la imagen: archivo de
# paginacion, hibernacion, actualizaciones y datos de uso.
$MargenWin  = 1.15
$MinLibreMB = 10240
# Letras que el despliegue reserva para System, Windows y ADMINISTRACION.
$LetrasReservadas = @('A','B','X','S','R','Q','P','O','W','V','U','T','N','K','L','M','J','I','H')

function Ejecutar-Diskpart([string[]]$lineas) {
    $f = Join-Path $env:TEMP ('ImagenMaestra_prt_{0}.txt' -f [guid]::NewGuid().ToString('N'))
    Set-Content -LiteralPath $f -Value $lineas -Encoding ASCII
    try { return @(& diskpart.exe /s $f | ForEach-Object { [string]$_ }) }
    finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function A-MB([double]$n, [string]$u) {
    switch ($u.ToUpper()) { 'B' { return $n / 1MB } 'KB' { return $n / 1KB } 'GB' { return $n * 1024 } 'TB' { return $n * 1048576 } default { return $n } }
}
function Texto-GB([double]$mb) { return ('{0:N1} GB' -f ($mb / 1024)) }
function Letra-Libre([string[]]$excluir) {
    foreach ($l in 'G', 'F', 'E', 'Y', 'Z', 'D', 'C') {
        if ($excluir -contains $l) { continue }
        if (-not (Test-Path "$($l):\")) { return $l }
    }
    return $null
}

# --- Lectura del disco con diskpart (funciona en Hiren's y en Windows) ---
function Disco-De-Unidad([string]$unidad) {
    foreach ($l in Ejecutar-Diskpart @("select volume $($unidad.Substring(0, 1))", 'detail volume')) {
        if ($l -match '^\s*\*\s*\S+\s+(\d+)\s') { return [int]$matches[1] }
    }
    return $null
}
function Particiones-Del-Disco([int]$disco) {
    $res = @()
    foreach ($l in Ejecutar-Diskpart @("select disk $disco", 'list partition')) {
        if ($l -match '^\s*\*?\s*\S+\s+(\d+)\s+.*?\s(\d+)\s+(B|KB|MB|GB|TB)\s+(\d+)\s+(B|KB|MB|GB|TB)\s*$') {
            $res += [pscustomobject]@{ Numero = [int]$matches[1]; MB = [long][math]::Round((A-MB $matches[2] $matches[3]), 0) }
        }
    }
    return $res
}
function Detalle-Particion([int]$disco, [int]$num) {
    $d = [pscustomobject]@{ Tipo = ''; Attr = '0x0000000000000000'; Letra = $null; TieneVolumen = $false }
    foreach ($l in Ejecutar-Diskpart @("select disk $disco", "select partition $num", 'detail partition')) {
        if ($l -match '^\s*(Type|Tipo)\s*:\s*(\S+)') { $d.Tipo = $matches[2].ToLower() }
        elseif ($l -match '^\s*(Attrib|Atrib)\S*\s*:\s*0[xX]([0-9A-Fa-f]+)') { $d.Attr = '0x' + $matches[2].ToUpper().PadLeft(16, '0') }
        elseif ($l -match '^\s*\*?\s*(Volume|Volumen)\s+\d+\s') {
            $d.TieneVolumen = $true
            if ($l -match '^\s*\*?\s*\S+\s+\d+\s+([A-Z])\s{2,}') { $d.Letra = $matches[1] }
        }
    }
    return $d
}
function Poner-Letra([int]$disco, [int]$num, [string]$letra) {
    [void](Ejecutar-Diskpart @("select disk $disco", "select partition $num", "assign letter=$letra"))
    return (Test-Path "$($letra):\")
}
function Quitar-Letra([int]$disco, [int]$num, [string]$letra) {
    [void](Ejecutar-Diskpart @("select disk $disco", "select partition $num", "remove letter=$letra"))
}

# Recorre las particiones del disco donde esta Windows (Origen) y decide que
# hacer con cada una. Accion: Recrea (EFI, MSR, arranque BIOS), Windows,
# Contenidos (ADMINISTRACION, se captura aparte), Extra (se captura) o
# Problema (no se puede capturar: el proceso debe detenerse).
function Inventario([string]$origen, [scriptblock]$alEncontrar) {
    $origen = $origen.Substring(0, 1).ToUpper()
    $disco = Disco-De-Unidad $origen
    if ($null -eq $disco) { throw "No se pudo saber en que disco esta $($origen):" }
    $res = @()
    foreach ($p in Particiones-Del-Disco $disco) {
        $d = Detalle-Particion $disco $p.Numero
        $it = [pscustomobject]@{
            Disco = $disco; Numero = $p.Numero; MB = $p.MB; Tipo = $d.Tipo; Attr = $d.Attr
            Accion = 'Extra'; Nota = ''; Etiqueta = ''; Fs = ''; UsadoMB = 0; Recovery = $false
        }
        $res += $it
        if ($d.Tipo -eq $GuidEfi) { $it.Accion = 'Recrea'; $it.Nota = 'Particion EFI de arranque (el despliegue crea una nueva)'; continue }
        if ($d.Tipo -eq $GuidMsr) { $it.Accion = 'Recrea'; $it.Nota = 'Reservada MSR (el despliegue crea una nueva)'; continue }
        if ($d.Tipo -in @('05', '0f', '85')) { $it.Accion = 'Recrea'; $it.Nota = 'Contenedor extendido (se recrea si hace falta)'; continue }
        if ($d.Letra -eq $origen) { $it.Accion = 'Windows'; $it.Nota = 'Windows (indice principal de la imagen)'; continue }
        if (-not $d.TieneVolumen) { $it.Accion = 'Problema'; $it.Nota = "Sin volumen legible (tipo $($d.Tipo))"; continue }
        $it.Recovery = ($d.Tipo -eq $GuidRecovery -or $d.Tipo -eq '27')

        $letra = $d.Letra; $temporal = $null
        if (-not $letra) {
            $letra = Letra-Libre $LetrasReservadas
            if (-not $letra) { $it.Accion = 'Problema'; $it.Nota = 'No hay letra libre para leerla'; continue }
            if (-not (Poner-Letra $disco $p.Numero $letra)) { $it.Accion = 'Problema'; $it.Nota = 'No se pudo montar para leerla'; continue }
            $temporal = $letra
        }
        try {
            $di = New-Object IO.DriveInfo("$($letra):\")
            if (-not $di.IsReady) { $it.Accion = 'Problema'; $it.Nota = 'No se puede leer (sin formato o cifrada con BitLocker)'; continue }
            $it.Etiqueta = $di.VolumeLabel
            $it.Fs = $di.DriveFormat
            $it.UsadoMB = [long][math]::Ceiling(($di.TotalSize - $di.AvailableFreeSpace) / 1MB)
            $it.MB = [long][math]::Max($it.MB, [math]::Ceiling($di.TotalSize / 1MB) + 8)
            if ($it.Etiqueta -eq 'ADMINISTRACION') { $it.Accion = 'Contenidos'; $it.Nota = 'Contenidos educativos (indice ADMINISTRACION)' }
            elseif ((Test-Path "$($letra):\Boot\BCD") -and -not (Test-Path "$($letra):\Windows\System32\config\SYSTEM")) { $it.Accion = 'Recrea'; $it.Nota = 'Arranque BIOS (el despliegue crea una nueva)' }
            elseif ($it.Fs -notin @('NTFS', 'FAT32', 'FAT', 'exFAT')) { $it.Accion = 'Problema'; $it.Nota = "Sistema de archivos $($it.Fs) no soportado" }
            elseif ($it.Recovery) { $it.Nota = 'Recuperacion' + $(if (Test-Path "$($letra):\Recovery\WindowsRE\winre.wim") { ' (WinRE)' } else { '' }) }
            else { $it.Nota = 'Datos' }
            if ($it.Accion -eq 'Extra' -and $alEncontrar) { & $alEncontrar $it $letra }
        } finally {
            if ($temporal) { Quitar-Letra $disco $p.Numero $temporal }
        }
    }
    return $res
}
function Mostrar-Inventario($lista) {
    foreach ($it in $lista) {
        $et = ''; if ($it.Etiqueta) { $et = " '$($it.Etiqueta)'" }
        $txt = 'Particion {0}: {1}, {2}{3} {4}' -f $it.Numero, $it.Nota, (Texto-GB $it.MB), $et, $it.Fs
        switch ($it.Accion) {
            'Extra'    { Write-Host "   [OK] $txt -> se captura (usados $(Texto-GB $it.UsadoMB))" -ForegroundColor Green }
            'Problema' { Write-Host "   [X] $txt -> NO se puede capturar" -ForegroundColor Red }
            default    { Write-Host "   [i] $txt" }
        }
    }
}

# --- Lectura de la imagen y calculo del plan --------------------------------
function Leer-Imagen([string]$imagen) {
    return Info-De-Salida @(& dism.exe /English /Get-ImageInfo "/ImageFile:$imagen")
}
# Analiza la salida de "dism /English /Get-ImageInfo" (indices con nombre,
# descripcion y tamano expandido en MB).
function Info-De-Salida([object[]]$salidaDism) {
    $res = @(); $cur = $null
    foreach ($l in $salidaDism) {
        $l = [string]$l
        if ($l -match '^\s*Index\s*:\s*(\d+)') {
            if ($cur) { $res += $cur }
            $cur = [pscustomobject]@{ Indice = [int]$matches[1]; Nombre = ''; Descripcion = ''; MB = 0 }
        } elseif ($cur -and $l -match '^\s*Name\s*:\s*(.*)$') { $cur.Nombre = $matches[1].Trim() }
        elseif ($cur -and $l -match '^\s*Description\s*:\s*(.*)$') { $cur.Descripcion = $matches[1].Trim() }
        elseif ($cur -and $l -match '^\s*Size\s*:\s*([\d,.]+)') { $cur.MB = [long][math]::Ceiling([double]($matches[1] -replace '[,.]', '') / 1MB) }
    }
    if ($cur) { $res += $cur }
    return $res
}
function Extras-De-Imagen($info) {
    $res = @()
    foreach ($i in $info) {
        if ($i.Nombre -notmatch '^PARTICION_\d+$' -or $i.Descripcion -notlike 'CPEPART;*') { continue }
        $h = @{}
        foreach ($par in $i.Descripcion.Substring(8).Split(';')) {
            $kv = $par.Split('=', 2)
            if ($kv.Count -eq 2) { $h[$kv[0]] = $kv[1] }
        }
        $res += [pscustomobject]@{
            Indice = $i.Indice; N = [int]$h['n']; Tipo = [string]$h['tipo']; Attr = [string]$h['attr']
            MB = [long]$h['mb']; UsadoMB = [long]$h['usado']; Fs = [string]$h['fs']; Etiqueta = [string]$h['etiqueta']
            Recovery = ($h['recovery'] -eq '1'); MinMB = 0; UsarMB = 0; Letra = ''
        }
    }
    return @($res | Sort-Object N)
}
# Las particiones de datos se pueden reducir hasta lo que ocupan (+20 %) para
# que la imagen quepa en discos mas pequenos; recovery y otras se dejan igual.
function Calcular-Plan($info, [int]$indiceWin, [string]$firmware, [long]$discoMB, [long]$contMB) {
    $win = @($info | Where-Object { $_.Indice -eq $indiceWin })[0]
    $winImg = 0; if ($win) { $winImg = $win.MB }
    $winMin = [long]([math]::Ceiling($winImg * $MargenWin) + $MinLibreMB)
    $arranque = 316; if ($firmware -eq 'BIOS') { $arranque = 500 }
    $extras = @(Extras-De-Imagen $info)
    foreach ($e in $extras) {
        $esDatos = -not $e.Recovery -and ($e.Tipo -eq $GuidDatos -or $e.Tipo -in @('07', '0b', '0c', '06', '0e'))
        if ($esDatos) { $e.MinMB = [long][math]::Min($e.MB, [math]::Max(1024, [math]::Ceiling($e.UsadoMB * 1.2) + 512)) }
        else { $e.MinMB = $e.MB }
    }
    $sumOrig = [long](($extras | Measure-Object -Property MB -Sum).Sum)
    $sumMin  = [long](($extras | Measure-Object -Property MinMB -Sum).Sum)
    $holgura = 16 + 4 * $extras.Count
    $reqOrig = $arranque + $winMin + $contMB + $sumOrig + $holgura
    $reqMin  = $arranque + $winMin + $contMB + $sumMin + $holgura
    $cabe = $true; $reducido = $false
    foreach ($e in $extras) { $e.UsarMB = $e.MB }
    if ($discoMB -gt 0 -and $discoMB -lt $reqOrig) {
        foreach ($e in $extras) { $e.UsarMB = $e.MinMB }
        if ($discoMB -ge $reqMin) { $reducido = ($sumMin -lt $sumOrig) } else { $cabe = $false }
    }
    $extraMB = [long](($extras | Measure-Object -Property UsarMB -Sum).Sum) + 4 * $extras.Count
    return [pscustomobject]@{
        WinImgMB = $winImg; WinMinMB = $winMin; ArranqueMB = $arranque; ContMB = $contMB
        Extras = $extras; ExtraMB = $extraMB; ReqOrigMB = $reqOrig; ReqMinMB = $reqMin
        DiscoMB = $discoMB; Cabe = $cabe; Reducido = $reducido
    }
}
function Mostrar-Plan($plan) {
    Write-Host ''
    Write-Host '   Espacio necesario en el disco destino:'
    Write-Host ('     Arranque (EFI/MSR o System) ......... {0}' -f (Texto-GB $plan.ArranqueMB))
    Write-Host ('     Windows (imagen {0} + margen) ..... minimo {1}' -f (Texto-GB $plan.WinImgMB), (Texto-GB $plan.WinMinMB))
    if ($plan.ContMB) { Write-Host ('     ADMINISTRACION ....................... {0}' -f (Texto-GB $plan.ContMB)) }
    foreach ($e in $plan.Extras) {
        $et = $e.Etiqueta; if (-not $et) { $et = '(sin etiqueta)' }
        $red = ''; if ($e.UsarMB -lt $e.MB) { $red = " (reducida desde $(Texto-GB $e.MB))" }
        $tipo = 'datos'; if ($e.Recovery) { $tipo = 'recuperacion' }
        Write-Host ('     Particion {0} {1}, {2} .... {3}{4}' -f $e.N, $et, $tipo, (Texto-GB $e.UsarMB), $red)
    }
    Write-Host ('   Disco minimo: {0} (con las particiones de datos reducidas: {1})' -f (Texto-GB $plan.ReqOrigMB), (Texto-GB $plan.ReqMinMB))
    if ($plan.DiscoMB -gt 0) {
        Write-Host ('   Disco destino: {0}' -f (Texto-GB $plan.DiscoMB))
        if (-not $plan.Cabe) { Write-Host ('   [X] La imagen NO cabe en este disco: faltan {0}.' -f (Texto-GB ($plan.ReqMinMB - $plan.DiscoMB))) -ForegroundColor Red }
        elseif ($plan.Reducido) { Write-Host '   [AVISO] Cabe reduciendo las particiones de datos a lo que ocupan (+20 %). No se pierde ningun archivo.' -ForegroundColor Yellow }
        else { Write-Host ('   [OK] La imagen cabe; Windows tendra unos {0}.' -f (Texto-GB ($plan.DiscoMB - $plan.ReqOrigMB + $plan.WinMinMB))) -ForegroundColor Green }
    }
}
# Fragmento de diskpart para crear las particiones extra (va despues de
# Windows y de ADMINISTRACION, asi ADMINISTRACION sigue siendo la numero 4).
function Lineas-Diskpart($plan, [string]$firmware) {
    $l = @()
    $usadas = @()
    $mbr = ($firmware -eq 'BIOS')
    $libres = 4 - 2; if ($plan.ContMB) { $libres-- }
    $n = 0
    foreach ($e in $plan.Extras) {
        $n++
        $letra = Letra-Libre ($LetrasReservadas + $usadas)
        if (-not $letra) { throw 'No hay letras libres para las particiones extra.' }
        $usadas += $letra; $e.Letra = $letra
        $fs = 'ntfs'
        switch ($e.Fs) { 'FAT32' { $fs = 'fat32' } 'FAT' { $fs = 'fat' } 'exFAT' { $fs = 'exfat' } }
        $esGuid = ($e.Tipo -match '^[0-9a-f]{8}-')
        if ($mbr) {
            if ($plan.Extras.Count -gt $libres -and $n -eq $libres) { $l += 'create partition extended' }
            if ($plan.Extras.Count -gt $libres -and $n -ge $libres) { $l += "create partition logical size=$($e.UsarMB)" }
            else { $l += "create partition primary size=$($e.UsarMB)" }
        } else {
            $l += "create partition primary size=$($e.UsarMB)"
        }
        if ($e.Etiqueta) { $l += "format quick fs=$fs label=`"$($e.Etiqueta)`"" } else { $l += "format quick fs=$fs" }
        $l += "assign letter=$letra"
        if ($mbr) {
            $id = $e.Tipo
            if ($esGuid) { $id = '07'; if ($e.Recovery) { $id = '27' } elseif ($fs -eq 'fat32') { $id = '0C' } }
            if ($id -and $id -ne '07') { $l += "set id=$id override" }
        } else {
            $guid = $e.Tipo; $attr = $e.Attr
            if (-not $esGuid) { $guid = $GuidDatos; $attr = '0x0000000000000000'; if ($e.Recovery) { $guid = $GuidRecovery; $attr = '0x8000000000000001' } }
            if ($guid -ne $GuidDatos) { $l += "set id=`"$guid`"" }
            if ($attr -and $attr -ne '0x0000000000000000') { $l += "gpt attributes=$attr" }
        }
    }
    return $l
}

if ($Accion -eq 'Funciones') { return }
$ErrorActionPreference = 'Stop'
try {
    switch ($Accion) {
        'Revisar' {
            $lista = Inventario $Origen $null
            Mostrar-Inventario $lista
            $extras = @($lista | Where-Object { $_.Accion -eq 'Extra' })
            if (@($lista | Where-Object { $_.Accion -eq 'Problema' }).Count) {
                Write-Host '   [X] Hay particiones que no se pueden capturar; se detiene para no perderlas.' -ForegroundColor Red
                exit 1
            }
            if ($extras.Count) { Write-Host "   [i] Se capturaran $($extras.Count) particion(es) extra en el mismo .wim." }
            else { Write-Host '   [i] No hay particiones de recovery ni de datos que capturar.' }
            exit 0
        }
        'Capturar' {
            $script:n = 0; $script:fallo = $false
            $lista = Inventario $Origen {
                param($it, $letra)
                $script:n++
                $et = ($it.Etiqueta -replace '[;="]', '').Trim()
                $rec = 0; if ($it.Recovery) { $rec = 1 }
                $desc = "CPEPART;n=$($script:n);tipo=$($it.Tipo);attr=$($it.Attr);mb=$($it.MB);usado=$($it.UsadoMB);fs=$($it.Fs);etiqueta=$et;recovery=$rec"
                Write-Host ''
                Write-Host "Capturando la particion $($it.Numero) ($($it.Nota) $et) como PARTICION_$($script:n)..."
                & dism.exe /Append-Image "/ImageFile:$Imagen" "/CaptureDir:$($letra):\" "/Name:PARTICION_$($script:n)" "/Description:$desc" /CheckIntegrity /Verify "/ScratchDir:$Scratch" "/LogPath:$(Join-Path $Logs "captura_$($NombreImagen)_particion$($script:n).log")"
                if ($LASTEXITCODE -ne 0) { $script:fallo = $true; Write-Host "   [X] DISM fallo al capturar la particion $($it.Numero)." -ForegroundColor Red }
                else { Write-Host "   [OK] Particion $($it.Numero) anadida como PARTICION_$($script:n)." -ForegroundColor Green }
            }
            if ($script:fallo) { exit 1 }
            if (@($lista | Where-Object { $_.Accion -eq 'Problema' }).Count) { Mostrar-Inventario $lista; exit 1 }
            if ($script:n -eq 0) { Write-Host '   [i] No habia particiones de recovery ni de datos que capturar.' }
            exit 0
        }
        'Plan' {
            $info = Leer-Imagen $Imagen
            if (-not $info.Count) { throw "No se pudo leer la imagen $Imagen" }
            $plan = Calcular-Plan $info $IndiceWin $Firmware $DiscoMB $ContMB
            Mostrar-Plan $plan
            if ($DirPlan) {
                New-Item -ItemType Directory -Force -Path $DirPlan | Out-Null
                $dp = @(); if ($plan.Cabe) { $dp = Lineas-Diskpart $plan $Firmware }
                Set-Content -LiteralPath (Join-Path $DirPlan 'extras_dp.txt') -Value $dp -Encoding ASCII
                Set-Content -LiteralPath (Join-Path $DirPlan 'extras_aplicar.txt') -Encoding ASCII -Value @(
                    $plan.Extras | ForEach-Object { '{0}|{1}|{2}' -f $_.Indice, $_.Letra, [int]$_.Recovery })
                $red = 0; if ($plan.Reducido) { $red = 1 }
                Set-Content -LiteralPath (Join-Path $DirPlan 'plan.cmd') -Encoding ASCII -Value @(
                    "set `"NEXTRA=$($plan.Extras.Count)`"", "set `"EXTRAMB=$($plan.ExtraMB)`"",
                    "set `"REQMB=$($plan.ReqOrigMB)`"", "set `"REQMINMB=$($plan.ReqMinMB)`"",
                    "set `"WINMINMB=$($plan.WinMinMB)`"", "set `"PLANRED=$red`"")
            }
            if (-not $plan.Cabe) { exit 2 }
            exit 0
        }
        'Aplicar' {
            $lista = Join-Path $DirPlan 'extras_aplicar.txt'
            if (-not (Test-Path -LiteralPath $lista)) { exit 0 }
            foreach ($linea in @(Get-Content -LiteralPath $lista | Where-Object { $_ })) {
                $idx, $letra, $rec = $linea.Split('|')
                Write-Host ''
                Write-Host "Aplicando la particion extra (indice $idx) en $($letra): ..."
                & dism.exe /Apply-Image "/ImageFile:$Imagen" "/Index:$idx" "/ApplyDir:$($letra):\" /CheckIntegrity "/LogPath:$(Join-Path $Logs "despliegue_particion$idx.log")"
                if ($LASTEXITCODE -ne 0) { Write-Host "   [X] DISM fallo al aplicar el indice $idx." -ForegroundColor Red; exit 1 }
                Write-Host "   [OK] Particion del indice $idx restaurada." -ForegroundColor Green
                if ($rec -eq '1' -and (Test-Path "$($letra):\Recovery\WindowsRE\winre.wim")) {
                    & "$($LetraWin):\Windows\System32\reagentc.exe" /setreimage /path "$($letra):\Recovery\WindowsRE" /target "$($LetraWin):\Windows"
                    if ($LASTEXITCODE -eq 0) { Write-Host '   [OK] Entorno de recuperacion de Windows (WinRE) registrado.' -ForegroundColor Green }
                    else { Write-Host '   [AVISO] No se pudo registrar WinRE; Windows lo intentara al arrancar.' -ForegroundColor Yellow }
                }
            }
            exit 0
        }
    }
} catch {
    Write-Host "   [X] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
