# ============================================================
# Figuras
# ============================================================

mu_palette <- c(
  "TPM" = "#243B53",
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
      strip.text = ggplot2::element_text(face = "bold")
    )
}

label_product <- function(x) {
  dplyr::recode(x, !!!product_labels, .default = x)
}

plot_rates_tpm <- function(monthly_panel) {
  keep <- intersect(c("tpm", "consumo_total", "comercial_total", "vivienda_uf", "cap_90_1y", "bcp_2y", "bcp_5y"), names(monthly_panel))

  dat <- monthly_panel |>
    dplyr::filter(date >= as.Date("2015-01-01")) |>
    dplyr::select(date, dplyr::all_of(keep)) |>
    tidyr::pivot_longer(-date, names_to = "serie", values_to = "value") |>
    dplyr::filter(!is.na(value)) |>
    dplyr::mutate(
      serie = dplyr::recode(
        serie,
        tpm = "TPM",
        consumo_total = "Consumo total",
        comercial_total = "Comercial total",
        vivienda_uf = "Vivienda UF",
        cap_90_1y = "Captación 90d-1a",
        bcp_2y = "BCP 2 años",
        bcp_5y = "BCP 5 años",
        .default = serie
      )
    )

  ggplot2::ggplot(dat, ggplot2::aes(date, value, group = serie, color = serie)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::scale_color_manual(values = mu_palette[names(mu_palette) %in% unique(dat$serie)]) +
    ggplot2::labs(
      title = "TPM y tasas bancarias seleccionadas",
      subtitle = "Tasas anuales, porcentaje",
      x = NULL,
      y = "Porcentaje",
      color = NULL
    ) +
    theme_bcch_like()
}

plot_cumulative_pt <- function(pt_tbl) {
  pt_tbl |>
    dplyr::mutate(product_lab = label_product(product)) |>
    ggplot2::ggplot(ggplot2::aes(horizon, cumulative, group = product_lab, color = product_lab)) +
    ggplot2::geom_hline(yintercept = 1, linewidth = 0.4, color = "grey55") +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3, color = "grey55") +
    ggplot2::geom_line(linewidth = 0.85) +
    ggplot2::labs(
      title = "Pass-through acumulado de la TPM",
      subtitle = "Coeficiente acumulado de rezagos distribuidos. Línea horizontal = traspaso uno a uno.",
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
      title = "Pass-through asimétrico: alzas vs bajas de TPM",
      subtitle = "Magnitud de traspaso en la dirección esperada. Interpretar con cautela: los ciclos no son simétricos.",
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
      subtitle = "Local projections con errores Newey-West",
      x = "Horizonte mensual",
      y = "Respuesta acumulada"
    ) +
    theme_bcch_like()
}
