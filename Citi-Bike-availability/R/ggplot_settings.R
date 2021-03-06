# build custom theme
theme_custom <- function() {
  theme_minimal() +
    theme(
      panel.grid.major.y = element_line(color = "gray95"),
      panel.grid.major.x = element_line(color = "gray95"),
      text = element_text(family = "Helvetica",
                          color = "gray30"))
}

theme_set(theme_custom())
