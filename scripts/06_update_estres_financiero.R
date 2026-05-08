# ============================================================
# 06_update_estres_financiero.R
# Actualiza el proyecto de estrés financiero para Chile.
#
# Uso recomendado desde la raíz del repositorio:
#   source("scripts/06_update_estres_financiero.R")
#
# Por defecto intenta descargar datos reales desde BCCh, FRED y BIS.
# Si falla y ESTRES_FALLBACK_LOCAL=TRUE, usa la base local de ExchangeReg.
# ============================================================

find_estres_project_root <- function(start = getwd()) {
  path <- normalizePath(start, winslash = "/", mustWork = TRUE)

  repeat {
    setup_file <- file.path(path, "R", "estres_financiero", "00_setup.R")
    if (file.exists(setup_file)) return(path)

    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }

  stop(
    "No pude identificar la raíz del repositorio Economics. ",
    "Ejecuta este script desde la raíz o verifica que exista R/estres_financiero/00_setup.R.",
    call. = FALSE
  )
}

repo_root <- find_estres_project_root()

# Para este proyecto la actualización estándar debe intentar datos reales.
# No se activa el respaldo local salvo que lo pidas explícitamente con
# Sys.setenv(ESTRES_FALLBACK_LOCAL = "TRUE").
if (!nzchar(Sys.getenv("ESTRES_USE_LIVE", unset = ""))) {
  Sys.setenv(ESTRES_USE_LIVE = "TRUE")
}
if (!nzchar(Sys.getenv("ESTRES_FALLBACK_LOCAL", unset = ""))) {
  Sys.setenv(ESTRES_FALLBACK_LOCAL = "FALSE")
}


source(file.path(repo_root, "R", "estres_financiero", "00_setup.R"), encoding = "UTF-8")
estres_load_packages()

source(estres_path("R", "estres_financiero", "01_fetch_sources.R", root = repo_root), encoding = "UTF-8")
source(estres_path("R", "estres_financiero", "01_data.R", root = repo_root), encoding = "UTF-8")
source(estres_path("R", "estres_financiero", "02_models.R", root = repo_root), encoding = "UTF-8")
source(estres_path("R", "estres_financiero", "03_plots.R", root = repo_root), encoding = "UTF-8")
source(estres_path("R", "estres_financiero", "04_run_pipeline.R", root = repo_root), encoding = "UTF-8")

run_estres_financiero_pipeline(root = repo_root)
