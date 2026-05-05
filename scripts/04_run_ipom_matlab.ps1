# ============================================================
# Ejecuta el bloque Matlab/IRIS del proyecto IPoM
# ============================================================
# Uso desde PowerShell, en la raíz del repositorio:
# .\scripts\04_run_ipom_matlab.ps1
#
# Requisitos:
# - Matlab disponible en PATH como `matlab`
# - IRIS Toolbox instalado y agregado al path de Matlab
# - CSV de entrada en matlab/ipom/outputs o la ruta que uses localmente

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repo "matlab\ipom\src"

Write-Host "Repositorio: $repo"
Write-Host "Carpeta Matlab: $src"

# Este comando llama un wrapper preparado para ejecución local.
# Si quieres usar tus scripts originales, edita run_ipom_pipeline.m.
matlab -batch "cd('$src'); run_ipom_pipeline"

Write-Host "Matlab/IRIS finalizó. Ahora corre: Rscript scripts/03_build_ipom_outputs.R"
