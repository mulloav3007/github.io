# ============================================================
# Gráficos y tablas para proyecto IPoM / IRIS
# ============================================================

ipom_plot_var <- function(
    data,
    variable_code,
    title = NULL,
    subtitle = NULL,
    ylab = NULL,
    start_period = "2018Q1",
    scenarios = NULL,
    baseline_id = "baseline_ipom"
) {
  stopifnot(all(c("period", "date", "scenario_id", "scenario", "variable", "value") %in% names(data)))

  plot_data <- data |>
    dplyr::filter(.data$variable == variable_code, .data$period >= start_period)

  if (!is.null(scenarios)) {
    plot_data <- plot_data |>
      dplyr::filter(.data$scenario_id %in% scenarios)
  }

  var_label <- plot_data$label[which(!is.na(plot_data$label))[1]]
  var_unit  <- plot_data$unit[which(!is.na(plot_data$unit))[1]]

  if (is.null(title)) title <- var_label
  if (is.null(ylab)) ylab <- var_unit

  plot_data <- plot_data |>
    dplyr::mutate(
      line_type = dplyr::if_else(.data$scenario_id == baseline_id, "Baseline", "Escenario")
    )

  g <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = .data$date,
      y = .data$value,
      color = .data$scenario,
      linetype = .data$line_type,
      group = .data$scenario
    )
  ) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.25, color = "grey75") +
    ggplot2::geom_line(linewidth = 0.85, na.rm = TRUE) +
    ggplot2::scale_linetype_manual(values = c("Baseline" = "solid", "Escenario" = "solid")) +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = NULL,
      y = ylab,
      color = NULL,
      linetype = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      legend.direction = "horizontal",
      legend.title = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", margin = ggplot2::margin(b = 6)),
      plot.subtitle = ggplot2::element_text(color = "grey35"),
      panel.grid.minor = ggplot2::element_blank()
    )

  plotly::ggplotly(g) |>
    plotly::layout(
      legend = list(
        orientation = "h",
        x = 0.5,
        xanchor = "center",
        y = -0.22,
        yanchor = "top"
      ),
      margin = list(t = 80, b = 95)
    )
}

ipom_plot_diff <- function(
    differences,
    variable_code,
    title = NULL,
    ylab = "Diferencia respecto del baseline",
    start_period = "2025Q1",
    scenarios = NULL
) {
  stopifnot(all(c("period", "date", "scenario_id", "scenario", "variable", "difference_vs_baseline") %in% names(differences)))

  plot_data <- differences |>
    dplyr::filter(.data$variable == variable_code, .data$period >= start_period)

  if (!is.null(scenarios)) {
    plot_data <- plot_data |>
      dplyr::filter(.data$scenario_id %in% scenarios)
  }

  var_label <- plot_data$label[which(!is.na(plot_data$label))[1]]
  if (is.null(title)) title <- paste0(var_label, ": desvío frente al baseline")

  g <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = .data$date,
      y = .data$difference_vs_baseline,
      color = .data$scenario,
      group = .data$scenario
    )
  ) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3, color = "grey60") +
    ggplot2::geom_line(linewidth = 0.85, na.rm = TRUE) +
    ggplot2::labs(title = title, x = NULL, y = ylab, color = NULL) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      legend.direction = "horizontal",
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", margin = ggplot2::margin(b = 8))
    )

  plotly::ggplotly(g) |>
    plotly::layout(
      legend = list(
        orientation = "h",
        x = 0.5,
        xanchor = "center",
        y = -0.22,
        yanchor = "top"
      ),
      margin = list(t = 80, b = 95)
    )
}

ipom_kable <- function(data, caption = NULL, digits = 2) {
  knitr::kable(data, digits = digits, caption = caption, format.args = list(big.mark = ".", decimal.mark = ","))
}

ipom_latest_values <- function(data, period = NULL, variables = c("D4L_CPI", "D4L_CPIXFE", "TPM", "L_GDP_GAP")) {
  if (is.null(period)) {
    period <- data |>
      dplyr::filter(.data$scenario_id == "baseline_ipom", .data$variable %in% variables, !is.na(.data$value)) |>
      dplyr::summarise(period = max(.data$period, na.rm = TRUE)) |>
      dplyr::pull(period)
  }

  data |>
    dplyr::filter(.data$period == period, .data$variable %in% variables) |>
    dplyr::select(Escenario = .data$scenario, Variable = .data$label, Valor = .data$value, Unidad = .data$unit) |>
    dplyr::arrange(.data$Variable, .data$Escenario)
}
