# ============================================================
# Figuras
# ============================================================

mu_palette <- c(
  "TPM" = "#243B53",
  "Tasa del producto" = "#B44434",
  "Consumo total" = "#B44434",
  "Comercial total" = "#2F7D7E",
  "Vivienda UF" = "#7A5195",
  "Captación 90d-1a" = "#C17C24",
  "BCP 2 años" = "#5377A3",
  "BCP 5 años" = "#6E6E6E",
  "Alzas de TPM" = "#8B1E1E",
  "Bajas de TPM" = "#1F5A7A"
)

theme_bcch_like <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold", size = 14, margin = ggplot2::margin(b = 6)),
      plot.subtitle = ggplot2::element_text(size = 10, margin = ggplot2::margin(b = 10)),
      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      legend.direction = "horizontal",
      panel.grid.minor = ggplot2::element_blank(),
      axis.title = ggplot2::element_text(size = 10),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.background = ggplot2::element_rect(fill = "white", colour = NA)
    )
}

label_product <- function(x) {
  dplyr::recode(x, !!!product_labels, .default = x)
}

plot_rates_tpm <- function(monthly_panel) {
  key_map <- c(
    cap_90_1y = "Captación 90d-1a",
    comercial_total = "Comercial total",
    consumo_total = "Consumo total",
    vivienda_uf = "Vivienda UF >3 años"
  )

  key_series <- intersect(names(key_map), names(monthly_panel))
  if (!"tpm" %in% names(monthly_panel) || length(key_series) == 0) {
    stop("No hay series suficientes para plot_rates_tpm().", call. = FALSE)
  }

  dat <- monthly_panel |>
    dplyr::filter(date >= as.Date("2015-01-01")) |>
    dplyr::select(date, tpm, dplyr::all_of(key_series)) |>
    tidyr::pivot_longer(cols = -date, names_to = "serie", values_to = "value") |>
    dplyr::filter(!is.na(value)) |>
    dplyr::mutate(
      panel = dplyr::case_when(
        serie == "tpm" ~ NA_character_,
        TRUE ~ unname(key_map[serie])
      )
    )

  tpm_dat <- dat |>
    dplyr::filter(serie == "tpm") |>
    dplyr::select(date, tpm = value)

  plot_dat <- dat |>
    dplyr::filter(serie != "tpm") |>
    dplyr::left_join(tpm_dat, by = "date") |>
    tidyr::pivot_longer(cols = c(value, tpm), names_to = "tipo", values_to = "rate") |>
    dplyr::mutate(
      tipo = dplyr::recode(tipo, value = "Tasa del producto", tpm = "TPM"),
      panel = factor(panel, levels = unname(key_map))
    )

  ggplot2::ggplot(plot_dat, ggplot2::aes(date, rate, colour = tipo)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::facet_wrap(~ panel, scales = "free_y", ncol = 2) +
    ggplot2::scale_color_manual(values = mu_palette[c("TPM", "Tasa del producto")]) +
    ggplot2::labs(
      title = "TPM y tasas bancarias clave por segmento",
      subtitle = "Cada panel usa su propia escala vertical para favorecer la lectura. La comparación entre paneles debe hacerse por dinámica, no por nivel.",
      x = NULL,
      y = "Porcentaje",
      colour = NULL
    ) +
    theme_bcch_like()
}

plot_key_spreads <- function(monthly_panel) {
  key_map <- c(
    cap_90_1y = "Captación 90d-1a",
    comercial_total = "Comercial total",
    consumo_total = "Consumo total",
    vivienda_uf = "Vivienda UF >3 años"
  )

  key_series <- intersect(names(key_map), names(monthly_panel))
  dat <- monthly_panel |>
    dplyr::filter(date >= as.Date("2015-01-01")) |>
    dplyr::select(date, tpm, dplyr::all_of(key_series)) |>
    tidyr::pivot_longer(cols = dplyr::all_of(key_series), names_to = "product", values_to = "rate") |>
    dplyr::filter(!is.na(rate), !is.na(tpm)) |>
    dplyr::mutate(
      spread = rate - tpm,
      panel = factor(unname(key_map[product]), levels = unname(key_map))
    )

  ggplot2::ggplot(dat, ggplot2::aes(date, spread)) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.35, colour = "grey55") +
    ggplot2::geom_line(linewidth = 0.9, colour = "#2F7D7E") +
    ggplot2::facet_wrap(~ panel, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title = "Spread respecto a la TPM",
      subtitle = "Diferencia entre la tasa del producto y la TPM. Útil para seguir márgenes y el grado de transmisión en niveles.",
      x = NULL,
      y = "Puntos porcentuales"
    ) +
    theme_bcch_like()
}

plot_cumulative_pt <- function(pt_tbl) {
  pt_tbl |>
    dplyr::filter(type == "total") |>
    dplyr::mutate(product_lab = label_product(product)) |>
    ggplot2::ggplot(ggplot2::aes(horizon, cumulative, group = product_lab, color = product_lab)) +
    ggplot2::geom_hline(yintercept = 1, linewidth = 0.4, color = "grey55") +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3, color = "grey55") +
    ggplot2::geom_line(linewidth = 0.85) +
    ggplot2::labs(
      title = "Pass-through acumulado de la TPM",
      subtitle = "Coeficiente acumulado de rezagos distribuidos. La línea horizontal en 1 corresponde a traspaso uno a uno.",
      x = "Meses desde el cambio de TPM",
      y = "Pass-through acumulado",
      color = NULL
    ) +
    theme_bcch_like()
}

plot_asymmetric_pt <- function(pt_asym_tbl) {
  pt_asym_tbl |>
    dplyr::mutate(
      product_lab = label_product(product),
      type_lab = dplyr::recode(type, alza_tpm = "Alzas de TPM", baja_tpm = "Bajas de TPM", .default = type)
    ) |>
    ggplot2::ggplot(ggplot2::aes(horizon, cumulative, group = type_lab, color = type_lab)) +
    ggplot2::geom_hline(yintercept = 1, linewidth = 0.35, color = "grey55") +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3, color = "grey55") +
    ggplot2::geom_line(linewidth = 0.85) +
    ggplot2::facet_wrap(~ product_lab, scales = "free_y") +
    ggplot2::scale_color_manual(values = mu_palette[c("Alzas de TPM", "Bajas de TPM")]) +
    ggplot2::labs(
      title = "Pass-through asimétrico: alzas versus bajas de TPM",
      subtitle = "Las bajas se reportan como magnitud de transmisión en la dirección esperada para facilitar la comparación visual.",
      x = "Meses desde el cambio de TPM",
      y = "Pass-through acumulado",
      color = NULL
    ) +
    theme_bcch_like()
}

plot_lp_irf <- function(lp_tbl) {
  lp_tbl |>
    dplyr::mutate(product_lab = label_product(product)) |>
    ggplot2::ggplot(ggplot2::aes(horizon, estimate)) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.4, color = "grey55") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = conf_low, ymax = conf_high), fill = "#6BAED6", alpha = 0.18) +
    ggplot2::geom_line(color = "#243B53", linewidth = 0.85) +
    ggplot2::facet_wrap(~ product_lab, scales = "free_y") +
    ggplot2::labs(
      title = "Respuesta dinámica de tasas bancarias a cambios de TPM",
      subtitle = "Local projections con errores Newey-West.",
      x = "Horizonte mensual",
      y = "Respuesta acumulada"
    ) +
    theme_bcch_like()
}
