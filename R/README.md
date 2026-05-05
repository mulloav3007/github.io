# Carpeta R

Aquí puedes ir moviendo scripts reutilizables para los proyectos del sitio.

Sugerencia de estructura futura:

- `00_config.R`: configuración global, paquetes y rutas.
- `01_fetch_series.R`: descarga de series públicas.
- `02_build_estres_externo.R`: construcción del índice de estrés externo.
- `03_build_tpm_pass_through.R`: preparación y estimación de transmisión de TPM.
- `04_build_curva_rendimiento.R`: preparación de curva de tasas.

No guardes claves, usuarios ni contraseñas dentro de estos archivos. Usa `.Renviron` y deja solo `.Renviron.example` en GitHub.
