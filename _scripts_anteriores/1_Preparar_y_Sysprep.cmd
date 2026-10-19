@echo off
rem Lanzador: clic derecho > Ejecutar como administrador.
rem Pasa los parametros opcionales al script PowerShell, por ejemplo:
rem   1_Preparar_y_Sysprep.cmd -QuitarAppsProblema -LimpiezaProfunda
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp01_Preparar_y_Sysprep.ps1" %*
pause
