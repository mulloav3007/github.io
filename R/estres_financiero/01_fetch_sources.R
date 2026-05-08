# ============================================================
# 01_fetch_sources.R
# Descarga robusta de datos reales desde BCCh, FRED y BIS.
#
# Variables esperadas en .Renviron:
#   BCCH_USER=...
#   BCCH_PASS=...
#   FRED_API_KEY=...
#
# El proyecto original usa:
#   - BCCh/Siete para tasas, cobre e índices accionarios.
#   - FRED para VIX, WTI, CPI US y Treasury fallback.
#   - BIS para USD/CLP, CNY/USD y dólar efectivo nominal.
# ============================================================

estres_missing_scalar <- function(x) {
  is.null(x) || length(x) != 1 || is.na(x) || !nzchar(trimws(as.character(x)))
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

estres_log <- function(...) {
  message(format(Sys.time(), "%H:%M:%S"), " | ", paste0(..., collapse = ""))
}

estres_parse_date_flexible <- function(x) {
  # Parser intencionalmente amplio para BCCh/BIS/FRED.
  # BCCh puede entregar fechas como dd-mm-YYYY, YYYY-mm-dd,
  # YYYY-mm-ddTHH:MM:SS, dd.mm.YYYY o con abreviaturas de mes.
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXct") || inherits(x, "POSIXlt")) return(as.Date(x))
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))

  x_chr <- trimws(as.character(x))
  x_chr <- gsub("\\ufeff", "", x_chr)
  x_chr[x_chr %in% c("", ".", "NA", "NaN", "null", "NULL", "-", "--")] <- NA_character_

  parsed <- rep(as.Date(NA), length(x_chr))

  assign_if_bad <- function(candidate) {
    bad <- is.na(parsed) & !is.na(candidate)
    if (any(bad, na.rm = TRUE)) parsed[bad] <<- candidate[bad]
    invisible(NULL)
  }

  # 1) ISO al inicio: YYYY-MM-DD o YYYY-MM-DDTHH:MM:SS
  iso_start <- ifelse(
    !is.na(x_chr) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", x_chr),
    substr(x_chr, 1, 10),
    NA_character_
  )
  assign_if_bad(suppressWarnings(as.Date(iso_start, format = "%Y-%m-%d")))

  # 2) Fecha ISO en cualquier parte del string.
  iso_any <- rep(NA_character_, length(x_chr))
  has_iso <- !is.na(x_chr) & grepl("[0-9]{4}-[0-9]{2}-[0-9]{2}", x_chr)
  iso_any[has_iso] <- sub(".*?([0-9]{4}-[0-9]{2}-[0-9]{2}).*", "\\1", x_chr[has_iso])
  assign_if_bad(suppressWarnings(as.Date(iso_any, format = "%Y-%m-%d")))

  # 3) Formatos numéricos comunes.
  formats <- c(
    "%d-%m-%Y", "%d/%m/%Y", "%d.%m.%Y",
    "%Y/%m/%d", "%Y.%m.%d",
    "%m/%d/%Y", "%m-%d-%Y"
  )
  for (fmt in formats) {
    assign_if_bad(suppressWarnings(as.Date(x_chr, format = fmt)))
  }

  # 4) Fechas con meses abreviados en español/inglés: 05.May.2026, 05-abr-2026, etc.
  month_map <- c(
    "ene" = "01", "jan" = "01", "january" = "01", "enero" = "01",
    "feb" = "02", "february" = "02", "febrero" = "02",
    "mar" = "03", "march" = "03", "marzo" = "03",
    "abr" = "04", "apr" = "04", "april" = "04", "abril" = "04",
    "may" = "05", "mayo" = "05",
    "jun" = "06", "june" = "06", "junio" = "06",
    "jul" = "07", "july" = "07", "julio" = "07",
    "ago" = "08", "aug" = "08", "august" = "08", "agosto" = "08",
    "sep" = "09", "set" = "09", "sept" = "09", "september" = "09", "septiembre" = "09",
    "oct" = "10", "october" = "10", "octubre" = "10",
    "nov" = "11", "november" = "11", "noviembre" = "11",
    "dic" = "12", "dec" = "12", "december" = "12", "diciembre" = "12"
  )
  txt_low <- tolower(gsub("\\.", "-", x_chr))
  txt_low <- gsub("/", "-", txt_low)
  parts <- strsplit(txt_low, "-")
  month_chr <- rep(NA_character_, length(x_chr))
  for (i in seq_along(parts)) {
    z <- parts[[i]]
    if (length(z) == 3 && !is.na(x_chr[i])) {
      d <- gsub("[^0-9]", "", z[1])
      m <- gsub("[^a-z]", "", z[2])
      y <- gsub("[^0-9]", "", z[3])
      if (nzchar(d) && nzchar(m) && nzchar(y) && m %in% names(month_map)) {
        month_chr[i] <- sprintf("%s-%s-%s", y, month_map[[m]], sprintf("%02d", as.integer(d)))
      }
    }
  }
  assign_if_bad(suppressWarnings(as.Date(month_chr, format = "%Y-%m-%d")))

  # 5) Compactos YYYYMM y YYYYMMDD.
  compact_6 <- !is.na(x_chr) & grepl("^[0-9]{6}$", x_chr)
  cand6 <- rep(NA_character_, length(x_chr))
  cand6[compact_6] <- paste0(substr(x_chr[compact_6], 1, 4), "-", substr(x_chr[compact_6], 5, 6), "-01")
  assign_if_bad(suppressWarnings(as.Date(cand6, format = "%Y-%m-%d")))

  compact_8 <- !is.na(x_chr) & grepl("^[0-9]{8}$", x_chr)
  cand8 <- rep(NA_character_, length(x_chr))
  cand8[compact_8] <- paste0(substr(x_chr[compact_8], 1, 4), "-", substr(x_chr[compact_8], 5, 6), "-", substr(x_chr[compact_8], 7, 8))
  assign_if_bad(suppressWarnings(as.Date(cand8, format = "%Y-%m-%d")))

  parsed
}

estres_parse_number_flexible <- function(x) {
  x_chr <- trimws(as.character(x))
  x_chr <- gsub("\\ufeff", "", x_chr)
  x_chr <- gsub("\\s+", "", x_chr)
  x_chr[x_chr %in% c("", ".", "NA", "NaN", "null", "NULL", "-", "--", "No disponible")] <- NA_character_

  has_comma <- grepl(",", x_chr, fixed = TRUE)
  has_dot <- grepl(".", x_chr, fixed = TRUE)

  # Caso latino: 1.234,56 -> 1234.56
  both <- !is.na(x_chr) & has_comma & has_dot
  x_chr[both] <- gsub("\\.", "", x_chr[both])
  x_chr[both] <- gsub(",", ".", x_chr[both], fixed = TRUE)

  # Caso decimal con coma: 5,67 -> 5.67
  comma_only <- !is.na(x_chr) & has_comma & !has_dot
  x_chr[comma_only] <- gsub(",", ".", x_chr[comma_only], fixed = TRUE)

  suppressWarnings(as.numeric(x_chr))
}

estres_validate_credentials <- function(config = estres_api_config()) {
  missing <- character(0)
  if (estres_missing_scalar(config$bcch_user)) missing <- c(missing, "BCCH_USER")
  if (estres_missing_scalar(config$bcch_pass)) missing <- c(missing, "BCCH_PASS")
  if (estres_missing_scalar(config$fred_api_key)) missing <- c(missing, "FRED_API_KEY")

  if (length(missing) > 0) {
    stop(
      "Faltan credenciales para descarga en vivo: ", paste(missing, collapse = ", "),
      "\nDefine esas variables en tu archivo .Renviron y reinicia RStudio.",
      call. = FALSE
    )
  }

  invisible(config)
}

estres_safe_filename <- function(x) {
  gsub("[^A-Za-z0-9_-]+", "_", as.character(x))
}

estres_write_download_diagnostic <- function(root, source, series_id, raw_body = NULL, text_body = NULL, url = NULL) {
  diag_dir <- file.path(root, "data/raw/estres_financiero/diagnostics")
  dir.create(diag_dir, recursive = TRUE, showWarnings = FALSE)

  stub <- paste0(source, "_", estres_safe_filename(series_id), "_", format(Sys.time(), "%Y%m%d_%H%M%S"))

  if (!is.null(raw_body)) {
    try(writeBin(raw_body, file.path(diag_dir, paste0(stub, ".raw"))), silent = TRUE)
  }

  if (!is.null(text_body)) {
    try(writeLines(text_body, file.path(diag_dir, paste0(stub, ".txt")), useBytes = TRUE), silent = TRUE)
  }

  if (!is.null(url)) {
    try(writeLines(url, file.path(diag_dir, paste0(stub, "_url.txt")), useBytes = TRUE), silent = TRUE)
  }

  invisible(file.path(diag_dir, stub))
}

estres_decode_raw_text <- function(raw_body) {
  if (is.null(raw_body) || length(raw_body) == 0) return("")

  txt_bytes <- rawToChar(raw_body)
  Encoding(txt_bytes) <- "bytes"

  encodings <- c("UTF-8", "latin1", "CP1252")
  candidates <- character(0)

  for (enc in encodings) {
    y <- tryCatch(iconv(txt_bytes, from = enc, to = "UTF-8", sub = "byte"), error = function(e) NA_character_)
    if (!is.na(y) && nzchar(y)) {
      y <- sub("^\\ufeff", "", y)
      candidates <- c(candidates, y)
    }
  }

  # Preferir el candidato que se parece a JSON. Si no, devolver el primero.
  looks_json <- grepl("^\\s*[\\{\\[]", candidates)
  if (any(looks_json, na.rm = TRUE)) return(candidates[which(looks_json)[1]])

  if (length(candidates) > 0) return(candidates[[1]])

  y <- rawToChar(raw_body)
  Encoding(y) <- "unknown"
  iconv(y, from = "", to = "UTF-8", sub = "byte")
}

estres_redacted_bcch_url <- function(series_id, first_date, last_date, user) {
  httr::modify_url(
    "https://si3.bcentral.cl/SieteRestWS/SieteRestWS.ashx",
    query = list(
      user = user,
      pass = "***",
      timeseries = series_id,
      firstdate = first_date,
      lastdate = last_date,
      `function` = "GetSeries"
    )
  )
}

estres_bcch_parse_json <- function(txt, series_id, root, diagnostic_url = NULL, raw_body = NULL) {
  txt <- sub("^\\ufeff", "", txt)
  txt_trim <- trimws(txt)

  if (!grepl("^\\s*[\\{\\[]", txt_trim)) {
    estres_write_download_diagnostic(
      root = root,
      source = "bcch_non_json",
      series_id = series_id,
      raw_body = raw_body,
      text_body = txt,
      url = diagnostic_url
    )
    preview <- substr(gsub("\\s+", " ", txt_trim), 1, 500)
    stop(
      "BCCh no devolvio JSON para ", series_id,
      ". Revise diagnostics/ para ver la respuesta. Inicio de respuesta: ", preview,
      call. = FALSE
    )
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(txt_trim, simplifyVector = FALSE),
    error = function(e) {
      estres_write_download_diagnostic(
        root = root,
        source = "bcch_json_parse_error",
        series_id = series_id,
        raw_body = raw_body,
        text_body = txt,
        url = diagnostic_url
      )
      stop("BCCh devolvio JSON no parseable para ", series_id, ": ", conditionMessage(e), call. = FALSE)
    }
  )

  parsed
}

estres_bcch_get_series <- function(series_id,
                                   first_date = "2010-01-01",
                                   last_date = format(Sys.Date(), "%Y-%m-%d"),
                                   user = estres_api_config()$bcch_user,
                                   pass = estres_api_config()$bcch_pass,
                                   root = estres_project_root(),
                                   quiet = FALSE) {
  if (estres_missing_scalar(user) || estres_missing_scalar(pass)) {
    stop("Faltan credenciales BCCh: define BCCH_USER y BCCH_PASS en .Renviron.", call. = FALSE)
  }

  base_url <- "https://si3.bcentral.cl/SieteRestWS/SieteRestWS.ashx"

  diagnostic_url <- estres_redacted_bcch_url(series_id, first_date, last_date, user)

  res <- tryCatch(
    httr::GET(
      base_url,
      query = list(
        user = user,
        pass = pass,
        timeseries = series_id,
        firstdate = first_date,
        lastdate = last_date,
        `function` = "GetSeries"
      ),
      httr::user_agent("Mozilla/5.0 R estres-financiero-chile"),
      httr::timeout(90)
    ),
    error = function(e) {
      stop("No pude conectar con BCCh para ", series_id, ": ", conditionMessage(e), call. = FALSE)
    }
  )

  raw_body <- httr::content(res, as = "raw")
  txt <- estres_decode_raw_text(raw_body)

  if (httr::http_error(res)) {
    estres_write_download_diagnostic(
      root = root,
      source = "bcch_http_error",
      series_id = series_id,
      raw_body = raw_body,
      text_body = txt,
      url = diagnostic_url
    )
    stop("BCCh devolvio HTTP ", httr::status_code(res), " para ", series_id, ". Revise diagnostics/.", call. = FALSE)
  }

  json_data <- estres_bcch_parse_json(
    txt = txt,
    series_id = series_id,
    root = root,
    diagnostic_url = diagnostic_url,
    raw_body = raw_body
  )

  # Errores explícitos de SieteRestWS.
  if (is.null(json_data$Series)) {
    msg <- json_data$Description %||% json_data$descripcion %||% json_data$Descripcion %||% json_data$message %||% json_data$Mensaje %||% NA_character_
    estres_write_download_diagnostic(
      root = root,
      source = "bcch_without_series",
      series_id = series_id,
      raw_body = raw_body,
      text_body = txt,
      url = diagnostic_url
    )
    stop(
      "BCCh no incluyo nodo Series para ", series_id,
      if (!is.na(msg)) paste0(". Mensaje BCCh: ", msg) else ".",
      " Revise diagnostics/.",
      call. = FALSE
    )
  }

  obs_list <- json_data$Series$Obs
  if (is.null(obs_list) || length(obs_list) == 0) {
    if (!quiet) warning("BCCh sin observaciones para serie: ", series_id, call. = FALSE)
    return(tibble::tibble(date = as.Date(character()), value_num = numeric()))
  }

  # Si BCCh devuelve una sola observación, asegurar lista de observaciones.
  if (is.list(obs_list) && !is.null(obs_list$indexDateString)) {
    obs_list <- list(obs_list)
  }

  out <- tibble::tibble(
    date_str = vapply(obs_list, function(x) as.character(x$indexDateString %||% x$date %||% x$Date %||% NA_character_), character(1)),
    value = vapply(obs_list, function(x) as.character(x$value %||% x$Value %||% x$OBS_VALUE %||% NA_character_), character(1)),
    status = vapply(obs_list, function(x) as.character(x$statusCode %||% x$StatusCode %||% NA_character_), character(1))
  ) |>
    dplyr::mutate(
      date = estres_parse_date_flexible(.data$date_str),
      value_num = estres_parse_number_flexible(.data$value)
    ) |>
    dplyr::select(date, value_num) |>
    dplyr::filter(!is.na(.data$date)) |>
    dplyr::arrange(.data$date)

  if (nrow(out) > 0 && sum(!is.na(out$value_num)) == 0) {
    estres_write_download_diagnostic(
      root = root,
      source = "bcch_values_all_na",
      series_id = series_id,
      raw_body = raw_body,
      text_body = txt,
      url = diagnostic_url
    )
    warning("BCCh devolvio fechas, pero todos los valores quedaron NA para ", series_id,
            ". Revise diagnostics/.", call. = FALSE)
  }

  out
}

estres_fred_get_series <- function(series_id,
                                   start_date = "2010-01-01",
                                   end_date = format(Sys.Date(), "%Y-%m-%d"),
                                   api_key = estres_api_config()$fred_api_key,
                                   quiet = FALSE) {
  if (estres_missing_scalar(api_key)) {
    stop("Falta FRED_API_KEY en .Renviron.", call. = FALSE)
  }

  res <- httr::GET(
    "https://api.stlouisfed.org/fred/series/observations",
    query = list(
      series_id = series_id,
      api_key = api_key,
      file_type = "json",
      observation_start = start_date,
      observation_end = end_date
    ),
    httr::timeout(90)
  )

  httr::stop_for_status(res)
  txt <- httr::content(res, as = "text", encoding = "UTF-8")
  json_data <- jsonlite::fromJSON(txt)
  df <- json_data$observations

  if (is.null(df) || nrow(df) == 0) {
    if (!quiet) warning("FRED sin observaciones para serie: ", series_id, call. = FALSE)
    return(tibble::tibble(date = as.Date(character()), value_num = numeric()))
  }

  df |>
    dplyr::mutate(
      date = as.Date(.data$date),
      value_num = estres_parse_number_flexible(.data$value)
    ) |>
    dplyr::select(date, value_num) |>
    dplyr::filter(!is.na(.data$date)) |>
    dplyr::arrange(.data$date)
}

estres_bis_get_series <- function(dataflow = c("WS_XRU", "WS_EER"),
                                  series_key,
                                  start = "2010-01-01",
                                  end = format(Sys.Date(), "%Y-%m-%d"),
                                  root = estres_project_root()) {
  dataflow <- match.arg(dataflow)
  base <- sprintf("https://stats.bis.org/api/v2/data/dataflow/BIS/%s/1.0", dataflow)
  url <- sprintf("%s/%s?startPeriod=%s&endPeriod=%s&format=csv", base, series_key, start, end)

  res <- httr::GET(url, httr::timeout(90), httr::user_agent("Mozilla/5.0 R estres-financiero-chile"))
  raw_body <- httr::content(res, as = "raw")
  csv_txt <- estres_decode_raw_text(raw_body)

  if (httr::http_error(res)) {
    estres_write_download_diagnostic(root, "bis_http_error", series_key, raw_body, csv_txt, url)
    stop("BIS devolvio HTTP ", httr::status_code(res), " para ", series_key, ". Revise diagnostics/.", call. = FALSE)
  }

  df <- tryCatch(
    read.csv(text = csv_txt, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) {
      estres_write_download_diagnostic(root, "bis_csv_error", series_key, raw_body, csv_txt, url)
      stop("No pude leer CSV de BIS para ", series_key, ": ", conditionMessage(e), call. = FALSE)
    }
  )

  names(df) <- make.names(names(df))

  time_candidates <- c("TIME_PERIOD", "Time.period", "TIME.PERIOD")
  obs_candidates <- c("OBS_VALUE", "Obs.value", "OBS.VALUE")

  time_col <- time_candidates[time_candidates %in% names(df)][1]
  obs_col <- obs_candidates[obs_candidates %in% names(df)][1]

  if (length(time_col) == 0 || length(obs_col) == 0 || is.na(time_col) || is.na(obs_col)) {
    estres_write_download_diagnostic(root, "bis_missing_columns", series_key, raw_body, csv_txt, url)
    stop(
      "La respuesta BIS no tiene columnas TIME_PERIOD/OBS_VALUE para ", series_key,
      ". Columnas recibidas: ", paste(names(df), collapse = ", "),
      call. = FALSE
    )
  }

  tibble::tibble(
    date = estres_parse_date_flexible(df[[time_col]]),
    value_num = estres_parse_number_flexible(df[[obs_col]])
  ) |>
    dplyr::filter(!is.na(.data$date)) |>
    dplyr::arrange(.data$date)
}

estres_series_non_na <- function(df, col) {
  if (is.null(df) || !col %in% names(df)) return(0L)
  sum(!is.na(df[[col]]))
}

estres_to_daily_level <- function(df, cal_dates, value_col = "value") {
  if (!all(c("date", value_col) %in% names(df))) {
    stop("df debe tener columnas date y ", value_col, call. = FALSE)
  }

  df <- df |>
    dplyr::transmute(date = as.Date(.data$date), value = suppressWarnings(as.numeric(.data[[value_col]]))) |>
    dplyr::filter(!is.na(.data$date), !is.na(.data$value)) |>
    dplyr::arrange(.data$date)

  if (nrow(df) < 2) {
    return(tibble::tibble(date = cal_dates$date, value_daily = NA_real_))
  }

  daily_full <- tibble::tibble(
    date = seq(min(df$date), max(cal_dates$date), by = "day")
  ) |>
    dplyr::left_join(df, by = "date") |>
    dplyr::arrange(.data$date)

  daily_full$value_interp <- zoo::na.approx(
    daily_full$value,
    x = as.numeric(daily_full$date),
    na.rm = FALSE
  )
  daily_full$value_interp <- zoo::na.locf(daily_full$value_interp, na.rm = FALSE)
  daily_full$value_interp <- zoo::na.locf(daily_full$value_interp, fromLast = TRUE, na.rm = FALSE)

  daily_full |>
    dplyr::select(date, value_daily = value_interp) |>
    dplyr::right_join(cal_dates, by = "date") |>
    dplyr::arrange(.data$date)
}

estres_monthly_to_daily_log <- function(df_monthly, cal_dates) {
  if (!all(c("date", "value") %in% names(df_monthly))) {
    stop("df_monthly debe tener columnas date y value", call. = FALSE)
  }

  df_monthly <- df_monthly |>
    dplyr::arrange(.data$date) |>
    dplyr::filter(!is.na(.data$value), .data$value > 0)

  if (nrow(df_monthly) < 2) {
    stop("Se necesitan al menos dos observaciones mensuales para interpolar CPI.", call. = FALSE)
  }

  daily_full <- tibble::tibble(
    date = seq(min(df_monthly$date), max(cal_dates$date), by = "day")
  ) |>
    dplyr::left_join(df_monthly, by = "date") |>
    dplyr::arrange(.data$date) |>
    dplyr::mutate(log_val = estres_safe_log(.data$value))

  daily_full$log_val_interp <- zoo::na.approx(
    daily_full$log_val,
    x = as.numeric(daily_full$date),
    na.rm = FALSE
  )

  daily_full$log_val_interp <- zoo::na.locf(daily_full$log_val_interp, na.rm = FALSE)

  daily_full |>
    dplyr::mutate(value_daily = exp(.data$log_val_interp)) |>
    dplyr::select(date, value_daily) |>
    dplyr::right_join(cal_dates, by = "date") |>
    dplyr::arrange(.data$date)
}

estres_fetch_live_raw_market_data <- function(root = estres_project_root(),
                                              start_date = Sys.getenv("ESTRES_START_DATE", unset = "2010-01-01"),
                                              end_date = format(Sys.Date(), "%Y-%m-%d"),
                                              config = estres_api_config(),
                                              save_raw = TRUE) {
  estres_validate_credentials(config)
  estres_make_dirs(root)

  estres_log("Descargando datos reales con la logica original: BCCh + FRED + BIS")

  # -------------------------
  # BCCh: tasas, commodities e indices accionarios
  # -------------------------
  estres_log("BCCh: tasa soberana Chile 10Y")
  y10_clp <- estres_bcch_get_series("F022.BCLP.TIS.AN10.NO.Z.D", start_date, end_date, config$bcch_user, config$bcch_pass, root = root) |>
    dplyr::transmute(date, y10_clp = value_num)

  y10_clp_monthly_candidate <- NULL
  if (estres_series_non_na(y10_clp, "y10_clp") < 250) {
    estres_log("BCCh: BCP 10Y diario trae pocas observaciones utiles; probando BCP 10Y mensual como respaldo interno")
    y10_clp_monthly_candidate <- tryCatch(
      estres_bcch_get_series("F022.BCP.TIN.AN10.NO.Z.M", start_date, end_date, config$bcch_user, config$bcch_pass, root = root) |>
        dplyr::transmute(date, y10_clp = value_num),
      error = function(e) e
    )
  }

  estres_log("BCCh: Treasury 10Y")
  y10_tsy_bcch <- estres_bcch_get_series("F019.TBG.TAS.10.D", start_date, end_date, config$bcch_user, config$bcch_pass, root = root) |>
    dplyr::transmute(date, y10_tsy_bcch = value_num)

  estres_log("BCCh: cobre")
  pcu <- estres_bcch_get_series("F019.PPB.PRE.100.D", start_date, end_date, config$bcch_user, config$bcch_pass, root = root) |>
    dplyr::transmute(date, pcu = value_num)

  estres_log("BCCh: Nasdaq")
  eq_nsq <- estres_bcch_get_series("F019.IBC.IND.51.D", start_date, end_date, config$bcch_user, config$bcch_pass, root = root) |>
    dplyr::transmute(date, eq_nsq = value_num)

  estres_log("BCCh: bolsa China")
  eq_cny <- estres_bcch_get_series("F019.IBC.IND.CHN.D", start_date, end_date, config$bcch_user, config$bcch_pass, root = root) |>
    dplyr::transmute(date, eq_cny = value_num)

  estres_log("BCCh: IPC Chile")
  ipc_chl <- estres_bcch_get_series("G073.IPC.IND.2023.M", start_date, end_date, config$bcch_user, config$bcch_pass, root = root) |>
    dplyr::transmute(date, value = value_num)

  # -------------------------
  # FRED: VIX, WTI, CPI US, Treasury fallback
  # -------------------------
  estres_log("FRED: VIX")
  vix <- estres_fred_get_series("VIXCLS", start_date, end_date, config$fred_api_key) |>
    dplyr::transmute(date, vix = value_num)

  estres_log("FRED: WTI")
  wti <- estres_fred_get_series("DCOILWTICO", start_date, end_date, config$fred_api_key) |>
    dplyr::transmute(date, wti = value_num)

  estres_log("FRED: CPI US")
  cpi_us <- estres_fred_get_series("CPIAUCSL", start_date, end_date, config$fred_api_key) |>
    dplyr::transmute(date, value = value_num)

  estres_log("FRED: Treasury 10Y fallback")
  y10_tsy_fred <- estres_fred_get_series("DGS10", start_date, end_date, config$fred_api_key) |>
    dplyr::transmute(date, y10_tsy_fred = value_num)

  # -------------------------
  # BIS: FX CLP, CNY y dolar efectivo nominal de EEUU
  # -------------------------
  estres_log("BIS: USD/CLP")
  clp <- estres_bis_get_series("WS_XRU", "D.CL.CLP.A", start_date, end_date, root = root) |>
    dplyr::transmute(date, clp = value_num)

  estres_log("BIS: CNY/USD")
  cny <- estres_bis_get_series("WS_XRU", "D.CN.CNY.A", start_date, end_date, root = root) |>
    dplyr::transmute(date, cny = value_num)

  estres_log("BIS: dolar efectivo nominal EEUU")
  dtw <- estres_bis_get_series("WS_EER", "D.N.B.US", start_date, end_date, root = root) |>
    dplyr::transmute(date, dtw = value_num)

  cal_trading <- clp |>
    dplyr::filter(!is.na(.data$clp)) |>
    dplyr::select(date) |>
    dplyr::distinct() |>
    dplyr::arrange(.data$date)

  if (nrow(cal_trading) < 250) {
    stop("La serie BIS de USD/CLP trae muy pocas observaciones. Revisa conexion o API BIS.", call. = FALSE)
  }

  # Respaldo interno solo para el caso en que el endpoint diario de BCCh
  # devuelva fechas pero valores no parseables o insuficientes. Mantiene el
  # concepto BCP 10Y del proyecto original; no cambia a swap/cámara.
  if (estres_series_non_na(y10_clp, "y10_clp") < 250 &&
      !is.null(y10_clp_monthly_candidate) &&
      !inherits(y10_clp_monthly_candidate, "error") &&
      estres_series_non_na(y10_clp_monthly_candidate, "y10_clp") >= 24) {
    estres_log("Usando respaldo interno BCCh mensual BCP 10Y interpolado a calendario diario")
    y10_clp <- estres_to_daily_level(y10_clp_monthly_candidate, cal_trading, value_col = "y10_clp") |>
      dplyr::rename(y10_clp = value_daily)
  }

  cpi_chl_daily <- estres_monthly_to_daily_log(ipc_chl, cal_trading) |>
    dplyr::rename(cpi_chl_daily = value_daily)

  cpi_us_daily <- estres_monthly_to_daily_log(cpi_us, cal_trading) |>
    dplyr::rename(cpi_us_daily = value_daily)

  cpi_rel <- cpi_chl_daily |>
    dplyr::inner_join(cpi_us_daily, by = "date") |>
    dplyr::mutate(cpi_rel_chl_us = log(.data$cpi_chl_daily / .data$cpi_us_daily)) |>
    dplyr::select(date, cpi_rel_chl_us)

  raw <- cal_trading |>
    dplyr::left_join(clp, by = "date") |>
    dplyr::left_join(y10_clp, by = "date") |>
    dplyr::left_join(y10_tsy_bcch, by = "date") |>
    dplyr::left_join(y10_tsy_fred, by = "date") |>
    dplyr::left_join(vix, by = "date") |>
    dplyr::left_join(dtw, by = "date") |>
    dplyr::left_join(pcu, by = "date") |>
    dplyr::left_join(wti, by = "date") |>
    dplyr::left_join(cny, by = "date") |>
    dplyr::left_join(eq_cny, by = "date") |>
    dplyr::left_join(eq_nsq, by = "date") |>
    dplyr::left_join(cpi_rel, by = "date") |>
    dplyr::mutate(
      y10_tsy = dplyr::coalesce(.data$y10_tsy_bcch, .data$y10_tsy_fred),
      data_source = "live_bcch_fred_bis"
    ) |>
    dplyr::select(
      date, clp, y10_clp, y10_tsy, vix, dtw, pcu, wti, cny,
      eq_cny, eq_nsq, cpi_rel_chl_us, data_source
    ) |>
    dplyr::arrange(.data$date)

  coverage <- raw |>
    dplyr::summarise(
      dplyr::across(
        .cols = c(clp, y10_clp, y10_tsy, vix, dtw, pcu, wti, cny, eq_cny, eq_nsq, cpi_rel_chl_us),
        .fns = ~ sum(!is.na(.x)),
        .names = "n_{.col}"
      ),
      first_date = min(.data$date, na.rm = TRUE),
      last_date = max(.data$date, na.rm = TRUE),
      n_rows = dplyr::n()
    )

  if (coverage$n_y10_clp[[1]] < 250) {
    readr::write_csv(coverage, file.path(root, "data/raw/estres_financiero/live_series_coverage.csv"))
    stop(
      "La descarga live no logro construir y10_clp con suficientes observaciones. ",
      "Obs utiles y10_clp: ", coverage$n_y10_clp[[1]], ". ",
      "Revise data/raw/estres_financiero/live_series_coverage.csv y diagnostics/.",
      call. = FALSE
    )
  }

  meta <- tibble::tribble(
    ~variable, ~source, ~series_id, ~description,
    "clp", "BIS WS_XRU", "D.CL.CLP.A", "USD/CLP, pesos por dolar",
    "cny", "BIS WS_XRU", "D.CN.CNY.A", "CNY/USD, yuanes por dolar",
    "dtw", "BIS WS_EER", "D.N.B.US", "Dolar efectivo nominal de Estados Unidos",
    "y10_clp", "BCCh Siete", "F022.BCLP.TIS.AN10.NO.Z.D", "Tasa soberana chilena a 10 anos",
    "y10_tsy", "BCCh Siete / FRED fallback", "F019.TBG.TAS.10.D / DGS10", "Treasury 10Y de Estados Unidos",
    "pcu", "BCCh Siete", "F019.PPB.PRE.100.D", "Precio del cobre",
    "eq_nsq", "BCCh Siete", "F019.IBC.IND.51.D", "Nasdaq",
    "eq_cny", "BCCh Siete", "F019.IBC.IND.CHN.D", "Indice accionario China",
    "cpi_rel_chl_us", "BCCh + FRED", "G073.IPC.IND.2023.M / CPIAUCSL", "Log IPC Chile / IPC EEUU",
    "vix", "FRED", "VIXCLS", "VIX",
    "wti", "FRED", "DCOILWTICO", "WTI"
  )

  if (save_raw) {
    readr::write_csv(raw, file.path(root, "data/raw/estres_financiero/market_data_live.csv"))
    readr::write_csv(meta, file.path(root, "data/raw/estres_financiero/source_catalog.csv"))
    readr::write_csv(coverage, file.path(root, "data/raw/estres_financiero/live_series_coverage.csv"))
  }

  estres_log("Descarga en vivo terminada. Ultima fecha raw: ", max(raw$date, na.rm = TRUE))
  raw
}
