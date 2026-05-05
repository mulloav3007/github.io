# Proyecto IPoM / IRIS Matlab

Esta carpeta contiene una versión ordenada del motor Matlab/IRIS que alimenta la página Quarto `proyectos/ipom-iris.qmd`.

## Estructura

```text
matlab/ipom/
├─ model/
│  └─ minimep0.model
├─ src/
│  ├─ readmodel_alternativo.m
│  ├─ readmodel_original.m
│  ├─ identificar_shocks_ipom_original.m
│  ├─ fcast_alt_ipom_original.m
│  ├─ makedata_original.m
│  ├─ run_ipom_pipeline.m
│  └─ exportar_outputs_quarto.m
└─ outputs/
   ├─ fcast_ipom_exact.csv
   ├─ fcast_alt_iran_fin_anticipado.csv
   ├─ fcast_alt_riskoff.csv
   ├─ fcast_alt_escenario.csv
   ├─ fcast_base_model.csv
   └─ history.csv
```

## Idea del flujo

1. Matlab/IRIS resuelve el modelo y produce archivos `fcast_*.csv`.
2. R convierte esos CSV a formato largo y ancho para Quarto.
3. Quarto solo lee `data/processed/ipom/*.csv` y genera la página HTML.

## Actualización recomendada

Desde la raíz del repo:

```powershell
.\scripts\04_run_ipom_matlab.ps1
Rscript scripts/03_build_ipom_outputs.R
quarto render
```

El wrapper `run_ipom_pipeline.m` está preparado como punto de entrada, pero no ejecuta automáticamente los scripts originales porque esos archivos pueden depender de supuestos locales. Edita ese wrapper y activa las líneas que correspondan a tu flujo real.
