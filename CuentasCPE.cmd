@echo off
setlocal EnableExtensions
title Verificacion CPE
rem ==========================================================
rem  CuentasCPE.cmd - se usa en el Windows de cada equipo YA
rem  desplegado con ImagenMaestra.cmd. Lanza la verificacion
rem  completa con permisos de administrador y sin tener que
rem  cambiar la politica de ejecucion de PowerShell.
rem ==========================================================
set "SCR=%~dp0ScriptsEducativos"

reg query "HKLM\SYSTEM\CurrentControlSet\Control\MiniNT" >nul 2>&1 && (
  echo [X] Esto se ejecuta en el Windows del equipo desplegado, no en Hiren's.
  pause
  exit /b 1
)
fltmc >nul 2>&1 || (
  echo Solicitando permisos de administrador...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b 0
)

:menu
cls
echo ==========================================================
echo    VERIFICACION CPE  (equipo ya desplegado)
echo ==========================================================
echo.
echo    [1] Verificacion completa del equipo (informe, no cambia nada)
echo          despliegue, todas las particiones y WinRE, script de
echo          primer arranque y cuentas (solo AdministradorCPE)
echo    [0] Salir
echo.
set "OPC="
set /p OPC="Elige una opcion: "
if "%OPC%"=="0" exit /b 0
if "%OPC%"=="1" call :ps "%SCR%\Verificar-Equipo.ps1"
goto :menu

:ps
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File %*
echo.
pause
exit /b 0
