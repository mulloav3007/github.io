# ============================================================
# Modelos de rezagos distribuidos
# ============================================================

add_lags <- function(df, vars, lags = 0:6) {
  out <- df
  for (v in vars) {
    if (!v %in% names(out)) next
    for (l in lags) {
      out[[paste0(v, "_l", l)]] <- dplyr::lag(out[[v]], l)
    }
  }
  out
}

nw_tidy <- function(model, lag = 6) {
  vc <- sandwich::NeweyWest(model, lag = lag, prewhite = FALSE, adjust = TRUE)
  broom::tidy(lmtest::coeftest(model, vcov. = vc))
}

available_controls_formula <- function(dat) {
  controls <- c()
  if ("dbcp_2y" %in% names(dat) && any(!is.na(dat$dbcp_2y))) controls <- c(controls, "dbcp_2y")
  if ("dbcp_5y" %in% names(dat) && any(!is.na(dat$dbcp_5y))) controls <- c(controls, "dbcp_5y")
  if ("dbcp_10y" %in% names(dat) && any(!is.na(dat$dbcp_10y))) controls <- c(controls, "dbcp_10y")

  if (length(controls) == 0) return("1")
  paste(controls, collapse = " + ")
}

estimate_dlm_product <- function(df, product_name, k = 6, asymmetric = FALSE) {
  dat <- df |>
    dplyr::filter(product == product_name) |>
    dplyr::arrange(date)

  # Compatibilidad: si el panel fue generado con una versión antigua, se crean las nuevas variables.
  if (!"dtpm_up" %in% names(dat)) dat$dtpm_up <- pmax(dat$dtpm, 0)
  if (!"dtpm_down" %in% names(dat)) dat$dtpm_down <- pmax(-dat$dtpm, 0)

  dat <- dat |>
    add_lags(
      vars = if (asymmetric) c("dtpm_up", "dtpm_down") else c("dtpm"),
      lags = 0:k
    ) |>
    dplyr::mutate(
      month_fe = factor(lubridate::month(date)),
      drate_l1 = dplyr::lag(drate, 1)
    )

  if (!asymmetric) {
    rhs_tpm <- paste0("dtpm_l", 0:k, collapse = " + ")
  } else {
    rhs_tpm <- paste(
      paste0("dtpm_up_l", 0:k, collapse = " + "),
      paste0("dtpm_down_l", 0:k, collapse = " + "),
      sep = " + "
    )
  }

  controls <- available_controls_formula(dat)
  fml <- stats::as.formula(paste("drate ~", rhs_tpm, "+ drate_l1 +", controls, "+ month_fe"))

  model <- stats::lm(fml, data = dat)

  list(
    product = product_name,
    model = model,
    tidy = nw_tidy(model, lag = k),
    data = dat,
    formula = fml
  )
}

extract_cumulative_pt <- function(est_obj, k = 6, asymmetric = FALSE) {
  coefs <- stats::coef(est_obj$model)

  get_coef <- function(nm) {
    val <- unname(coefs[nm])
    if (length(val) == 0 || is.na(val)) 0 else val
  }

  if (!asymmetric) {
    vals <- tibble::tibble(
      horizon = 0:k,
      beta = purrr::map_dbl(0:k, ~ get_coef(paste0("dtpm_l", .x))),
      beta_signed = beta,
      type = "total",
      reported_scale = "signed"
    ) |>
      dplyr::mutate(cumulative = cumsum(beta))
  } else {
    vals_up <- tibble::tibble(
      horizon = 0:k,
      beta_signed = purrr::map_dbl(0:k, ~ get_coef(paste0("dtpm_up_l", .x))),
      beta = beta_signed,
      type = "alza_tpm",
      reported_scale = "signed"
    )

    vals_down <- tibble::tibble(
      horizon = 0:k,
      # dtpm_down es la magnitud positiva de la baja. El coeficiente firmado esperado es negativo.
      beta_signed = purrr::map_dbl(0:k, ~ get_coef(paste0("dtpm_down_l", .x))),
      # Para comparar intensidad de transmisión, se reporta la magnitud en la dirección esperada.
      beta = -beta_signed,
      type = "baja_tpm",
      reported_scale = "magnitude_expected_direction"
    )

    vals <- dplyr::bind_rows(vals_up, vals_down) |>
      dplyr::group_by(type) |>
      dplyr::mutate(cumulative = cumsum(beta)) |>
      dplyr::ungroup()
  }

  vals |>
    dplyr::mutate(product = est_obj$product)
}

estimate_all_dlm <- function(model_data, k = 6, asymmetric = FALSE) {
  products <- sort(unique(model_data$product))
  purrr::map(products, ~ estimate_dlm_product(model_data, .x, k = k, asymmetric = asymmetric))
}
