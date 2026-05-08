# ============================================================
# 01_data.R
# Limpieza de datos de mercado para el monitor Chile.
# Puede usar descarga en vivo o base local congelada como respaldo.
# ============================================================

estres_market_columns <- c(
  "clp", "y10_clp", "y10_tsy", "vix", "dtw",
  "pcu", "wti", "cny", "eq_cny", "eq_nsq"
)

estres_optional_columns <- c("cpi_rel_chl_us", "data_source")

estres_log_columns <- c("clp", "pcu", "wti", "vix", "dtw", "cny", "eq_cny", "eq_nsq")

estres_exchange_column_map <- c(
  "Unnamed: 0" = "date",
  "...1" = "date",
  "PCU" = "pcu",
  "AUX" = "aux",
  "WTI" = "wti",
  "BRL" = "brl",
  "CLP" = "clp",
  "CNY" = "cny",
  "COL" = "cop",
  "MXN" = "mxn",
  "PEN" = "pen",
  "EQBRL" = "eq_brl",
  "EQCLP" = "eq_clp",
  "EQCNY" = "eq_cny",
  "EQCOL" = "eq_col",
  "EQDJI" = "eq_dji",
  "EQNSQ" = "eq_nsq",
  "EQMXN" = "eq_mxn",
  "EQPEN" = "eq_pen",
  "10YBRL" = "y10_brl",
  "10YCLP" = "y10_clp",
  "10YCOL" = "y10_col",
  "10YTSY" = "y10_tsy",
  "10YMXN" = "y10_mxn",
  "10YPEN" = "y10_pen",
  "VIX" = "vix",
  "DTW" = "dtw"
)

estres_normalize_name <- function(x) {
  x <- trimws(as.character(x))
  x <- gsub("\\ufeff", "", x, fixed = FALSE)
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  tolower(x)
}

estres_standardize_market_names <- function(raw_data) {
  raw_data <- tibble::as_tibble(raw_data)
  original_names <- names(raw_data)
  mapped_names <- original_names

  # Mapeo exacto para la estructura original de ExchangeReg.
  for (old in names(estres_exchange_column_map)) {
    mapped_names[original_names == old] <- unname(estres_exchange_column_map[[old]])
  }

  normalized <- estres_normalize_name(mapped_names)

  aliases <- c(
    "unnamed_0" = "date",
    "x" = "date",
    "x1" = "date",
    "1" = "date",
    "date" = "date",
    "fecha" = "date",
    "time_period" = "date",
    "pcu" = "pcu",
    "copper" = "pcu",
    "cobre" = "pcu",
    "wti" = "wti",
    "brl" = "brl",
    "clp" = "clp",
    "usdclp" = "clp",
    "usd_clp" = "clp",
    "d_cl_clp_a" = "clp",
    "cny" = "cny",
    "usdcny" = "cny",
    "usd_cny" = "cny",
    "d_cn_cny_a" = "cny",
    "vix" = "vix",
    "dtw" = "dtw",
    "dollar" = "dtw",
    "dolar" = "dtw",
    "dolar_global" = "dtw",
    "dollar_index" = "dtw",
    "eqcny" = "eq_cny",
    "eq_cny" = "eq_cny",
    "china_equity" = "eq_cny",
    "eqnsq" = "eq_nsq",
    "eq_nsq" = "eq_nsq",
    "nasdaq" = "eq_nsq",
    "10yclp" = "y10_clp",
    "y10clp" = "y10_clp",
    "y10_clp" = "y10_clp",
    "tasa_10y_clp" = "y10_clp",
    "10y_clp" = "y10_clp",
    "10y_cl" = "y10_clp",
    "10ytsy" = "y10_tsy",
    "y10tsy" = "y10_tsy",
    "y10_tsy" = "y10_tsy",
    "dgs10" = "y10_tsy",
    "10y_tsy" = "y10_tsy",
    "treasury_10y" = "y10_tsy",
    "cpi_rel_chl_us" = "cpi_rel_chl_us",
    "l_cpi_rel_chl_us" = "cpi_rel_chl_us",
    "data_source" = "data_source"
  )

  final_names <- vapply(normalized, function(nm) {
    if (nm %in% names(aliases)) aliases[[nm]] else nm
  }, character(1), USE.NAMES = FALSE)

  names(raw_data) <- make.unique(final_names, sep = "_")

  if (!"date" %in% names(raw_data) && ncol(raw_data) >= 1) {
    first_name <- names(raw_data)[1]
    first_norm <- estres_normalize_name(first_name)
    if (first_norm %in% c("", "x", "x1", "1", "unnamed_0")) {
      names(raw_data)[1] <- "date"
    }
  }

  raw_data
}

estres_parse_date_column <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXct") || inherits(x, "POSIXlt")) return(as.Date(x))
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))

  x_chr <- as.character(x)
  x_chr <- trimws(x_chr)
  x_chr <- gsub("\\ufeff", "", x_chr)
  x_chr[x_chr %in% c("", ".", "NA", "NaN", "null", "NULL", "-", "--")] <- NA_character_

  # Si existe el parser robusto de 01_fetch_sources.R, usarlo.
  if (exists("estres_parse_date_flexible", mode = "function")) {
    return(estres_parse_date_flexible(x_chr))
  }

  parsed <- rep(as.Date(NA), length(x_chr))
  assign_if_bad <- function(candidate) {
    bad <- is.na(parsed) & !is.na(candidate)
    if (any(bad, na.rm = TRUE)) parsed[bad] <<- candidate[bad]
    invisible(NULL)
  }

  iso_start <- ifelse(
    !is.na(x_chr) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", x_chr),
    substr(x_chr, 1, 10),
    NA_character_
  )
  assign_if_bad(suppressWarnings(as.Date(iso_start, format = "%Y-%m-%d")))

  iso_any <- rep(NA_character_, length(x_chr))
  has_iso <- !is.na(x_chr) & grepl("[0-9]{4}-[0-9]{2}-[0-9]{2}", x_chr)
  iso_any[has_iso] <- sub(".*?([0-9]{4}-[0-9]{2}-[0-9]{2}).*", "\\1", x_chr[has_iso])
  assign_if_bad(suppressWarnings(as.Date(iso_any, format = "%Y-%m-%d")))

  for (fmt in c("%d-%m-%Y", "%d/%m/%Y", "%d.%m.%Y", "%Y/%m/%d", "%Y.%m.%d", "%m/%d/%Y", "%m-%d-%Y")) {
    assign_if_bad(suppressWarnings(as.Date(x_chr, format = fmt)))
  }

  bad <- is.na(parsed) & !is.na(x_chr) & grepl("^[0-9]{6}$", x_chr)
  if (any(bad, na.rm = TRUE)) parsed[bad] <- suppressWarnings(as.Date(paste0(substr(x_chr[bad], 1, 4), "-", substr(x_chr[bad], 5, 6), "-01")))

  bad <- is.na(parsed) & !is.na(x_chr) & grepl("^[0-9]{8}$", x_chr)
  if (any(bad, na.rm = TRUE)) parsed[bad] <- suppressWarnings(as.Date(paste0(substr(x_chr[bad], 1, 4), "-", substr(x_chr[bad], 5, 6), "-", substr(x_chr[bad], 7, 8))))

  parsed
}

estres_import_exchange_excel <- function(
    xlsx_file,
    output_csv = estres_path("data/raw/estres_financiero/merged_full_dataset.csv")
) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop(
      "Para importar directamente el Excel original instala readxl: install.packages('readxl').",
      call. = FALSE
    )
  }

  raw <- readxl::read_excel(xlsx_file) |>
    estres_standardize_market_names()

  if (!"date" %in% names(raw)) {
    stop("No pude identificar la columna de fecha en el Excel original.", call. = FALSE)
  }

  raw <- raw |>
    dplyr::mutate(date = estres_parse_date_column(.data$date)) |>
    dplyr::filter(!is.na(.data$date)) |>
    dplyr::arrange(.data$date)

  estres_make_dirs()
  readr::write_csv(raw, output_csv)
  invisible(raw)
}

estres_read_raw_market_data <- function(
    raw_file = estres_path("data/raw/estres_financiero/merged_full_dataset.csv")
) {
  if (!file.exists(raw_file)) {
    stop(
      "No existe el archivo raw: ", raw_file,
      "\nCopia data/raw/estres_financiero/merged_full_dataset.csv, importa el Excel original o activa la descarga en vivo.",
      call. = FALSE
    )
  }

  raw <- readr::read_csv(raw_file, show_col_types = FALSE) |>
    estres_standardize_market_names()

  if (!"date" %in% names(raw)) {
    stop(
      "No pude identificar una columna de fecha en ", raw_file,
      ". Revisa que la primera columna sea la fecha o que exista una columna llamada date/fecha.",
      call. = FALSE
    )
  }

  raw |>
    dplyr::mutate(date = estres_parse_date_column(.data$date)) |>
    dplyr::filter(!is.na(.data$date)) |>
    dplyr::arrange(.data$date)
}

estres_get_raw_market_data <- function(root = estres_project_root(),
                                       use_live = estres_api_config()$use_live,
                                       fallback_to_local = estres_api_config()$fallback_to_local,
                                       start_date = Sys.getenv("ESTRES_START_DATE", unset = "2010-01-01"),
                                       end_date = format(Sys.Date(), "%Y-%m-%d")) {
  local_file <- file.path(root, "data/raw/estres_financiero/merged_full_dataset.csv")
  live_file <- file.path(root, "data/raw/estres_financiero/market_data_live.csv")

  if (isTRUE(use_live)) {
    live_attempt <- tryCatch(
      estres_fetch_live_raw_market_data(root = root, start_date = start_date, end_date = end_date),
      error = function(e) e
    )

    if (!inherits(live_attempt, "error")) {
      raw <- estres_standardize_market_names(live_attempt)
      raw$data_source <- "live_bcch_fred_bis"
      return(raw)
    }

    msg <- paste0("No se pudo descargar en vivo: ", conditionMessage(live_attempt))
    error_file <- file.path(root, "data/raw/estres_financiero/live_download_error.txt")
    dir.create(dirname(error_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(
      c(
        paste0("timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
        paste0("error: ", conditionMessage(live_attempt)),
        "",
        "Si el error viene de BCCh/BIS, revisar tambien data/raw/estres_financiero/diagnostics/."
      ),
      error_file,
      useBytes = TRUE
    )

    fallback_files <- c(live_file, local_file)
    fallback_files <- fallback_files[file.exists(fallback_files)]

    if (isTRUE(fallback_to_local) && length(fallback_files) > 0) {
      fallback_file <- fallback_files[[1]]
      warning(msg, "\nSe usara respaldo: ", fallback_file, call. = FALSE)
      raw <- estres_read_raw_market_data(fallback_file)
      raw$data_source <- if (identical(
        normalizePath(fallback_file, winslash = "/", mustWork = FALSE),
        normalizePath(live_file, winslash = "/", mustWork = FALSE)
      )) {
        "live_previous_file_fallback"
      } else {
        "local_exchange_reg_fallback"
      }
      return(raw)
    }

    stop(msg, "\nArchivo de diagnostico: ", error_file, call. = FALSE)
  }

  raw <- estres_read_raw_market_data(local_file)
  raw$data_source <- "local_exchange_reg"
  raw
}

estres_prepare_market_data <- function(raw_data, start_date = as.Date("2012-10-05")) {
  raw_data <- estres_standardize_market_names(raw_data)

  if ("date" %in% names(raw_data)) {
    raw_data <- raw_data |>
      dplyr::mutate(date = estres_parse_date_column(.data$date)) |>
      dplyr::filter(!is.na(.data$date))
  }

  missing_cols <- setdiff(c("date", estres_market_columns), names(raw_data))
  if (length(missing_cols) > 0) {
    stop(
      "Faltan columnas en el archivo raw: ", paste(missing_cols, collapse = ", "),
      "\nColumnas disponibles: ", paste(names(raw_data), collapse = ", "),
      call. = FALSE
    )
  }

  for (col in estres_optional_columns) {
    if (!col %in% names(raw_data)) {
      raw_data[[col]] <- if (col == "data_source") "unknown" else NA_real_
    }
  }

  raw_data |>
    dplyr::select(dplyr::all_of(c("date", estres_market_columns, estres_optional_columns))) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(c(estres_market_columns, "cpi_rel_chl_us")),
        ~ suppressWarnings(as.numeric(.x))
      )
    ) |>
    dplyr::arrange(.data$date) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(estres_market_columns),
        ~ estres_interpolate_numeric(.x, .data$date)
      ),
      cpi_rel_chl_us = estres_interpolate_numeric(.data$cpi_rel_chl_us, .data$date)
    ) |>
    dplyr::filter(.data$date >= start_date) |>
    dplyr::mutate(
      trend = dplyr::row_number(),
      l_clp = estres_safe_log(.data$clp),
      l_pcu = estres_safe_log(.data$pcu),
      l_wti = estres_safe_log(.data$wti),
      l_vix = estres_safe_log(.data$vix),
      l_dtw = estres_safe_log(.data$dtw),
      l_cny = estres_safe_log(.data$cny),
      l_eq_cny = estres_safe_log(.data$eq_cny),
      l_eq_nsq = estres_safe_log(.data$eq_nsq),
      l_cpi_rel_chl_us = .data$cpi_rel_chl_us
    )
}

estres_write_market_data <- function(market_data, root = estres_project_root()) {
  estres_make_dirs(root)

  readr::write_csv(
    market_data,
    file.path(root, "data/processed/estres_financiero/market_data_chile.csv")
  )

  source_summary <- market_data |>
    dplyr::summarise(
      source = paste(unique(.data$data_source), collapse = "; "),
      first_date = min(.data$date, na.rm = TRUE),
      last_date = max(.data$date, na.rm = TRUE),
      n_obs = dplyr::n(),
      updated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    )

  readr::write_csv(
    source_summary,
    file.path(root, "data/processed/estres_financiero/data_update_log.csv")
  )

  invisible(market_data)
}
