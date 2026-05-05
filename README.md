# Economics

Sitio personal y portafolio técnico de economía aplicada, macroeconomía, política monetaria y econometría.

Construido con Quarto y publicado en GitHub Pages desde la carpeta `docs/`.

## Estructura principal

- `index.qmd`: página principal.
- `proyectos.qmd`: resumen de proyectos.
- `proyectos/`: páginas individuales de proyectos.
- `R/`: funciones reutilizables para gráficos, datos y tablas.
- `scripts/`: scripts de actualización y render.
- `matlab/ipom/`: motor Matlab/IRIS del proyecto de escenarios tipo IPoM.
- `data/processed/`: bases limpias usadas por las páginas Quarto.
- `assets/css/styles.css`: estilo visual del sitio.
- `docs/`: sitio renderizado que publica GitHub Pages.

## Proyectos incluidos

- Nowcasting de actividad económica en Chile.
- Escenarios macroeconómicos inspirados en IPoM con Matlab/IRIS.
- Transmisión de la TPM a tasas de mercado.
- Curva de rendimiento chilena interactiva.
- Índice de estrés externo para Chile.

## Render general

```bash
quarto render
```

## Actualizar proyecto IPoM / IRIS

Si ya tienes nuevos outputs `fcast_*.csv` exportados desde Matlab/IRIS en `matlab/ipom/outputs/`, ejecuta:

```bash
Rscript scripts/03_build_ipom_outputs.R
quarto render
```

En Windows, si quieres partir desde Matlab:

```powershell
.\scripts\04_run_ipom_matlab.ps1
Rscript scripts/03_build_ipom_outputs.R
quarto render
```

## Publicación

Configurar GitHub Pages desde `main / docs`.

## Seguridad

No guardar claves, usuarios, contraseñas ni archivos brutos privados en el repositorio. Usa `.Renviron` local y deja solo `.Renviron.example` como plantilla pública.
