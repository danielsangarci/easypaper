# ---------------------------------------------------------------------------
# setup.R - everything the manuscript needs before its first line of text.
#
# manuscript.qmd loads it in its `setup` chunk, but it is a plain .R file: you
# can run source("R/setup.R") in the console and work interactively with the
# same objects (palette, sizes, helpers) the render sees.
#
# What used to live in global_settings.Rmd and was knitr configuration (echo,
# include, cache.path, fig.path, dev, dpi) now lives in _quarto.yml. Only R
# code is left here.
# ---------------------------------------------------------------------------

library(here)        # paths relative to the project root
library(knitr)
library(flextable)

# --- Seed ------------------------------------------------------------------
# ESSENTIAL as soon as there is randomness: permutations (vegan::adonis2,
# anosim), rarefaction, bootstrap, cross-validation, MCMC, glmmTMB/lme4 starts.
# Without it, two renders of the same code give different p-values and the
# reviewer cannot reproduce your tables.
set.seed(20260903)

# --- Figure sizes ----------------------------------------------------------
# Journals give widths in millimetres and Quarto wants inches.
# Use: #| fig-width: 7.09   (= 180 mm; write the mm in a comment)
# or, if you prefer to compute it:  #| fig-width: !expr mm(180)
mm <- function(x) x / 25.4

FIG_WIDTH_1COL <- mm(90)    # 3.54 in
FIG_WIDTH_2COL <- mm(180)   # 7.09 in

# --- Tables ----------------------------------------------------------------
set_flextable_defaults(
  font.size   = 12,
  font.family = "Times New Roman"
)

#' Fit a flextable to the width of the text column.
#'
#' The table fills the column and the reader -- Word, LaTeX -- sizes each
#' column from its content. That is what the .pdf already did, and what the
#' .docx did not: the table used to be given a fixed 6 inches, while Quarto
#' wraps every captioned table in a container 5.5 inches wide. A 6 inch table
#' inside a 5.5 inch cell is what made the columns come out misaligned in Word
#' and correct in the PDF, from the same code.
#'
#' @param ft a flextable.
#' @param pgwidth a width in inches, for the rare table that has to be a fixed
#'   size whatever it is put inside. `NULL`, the default, fills the column.
fit_flextable_to_page <- function(ft, pgwidth = NULL) {
  ft <- flextable::autofit(ft)
  if (is.null(pgwidth)) {
    # width = 1 is "all of what you are given", not one inch.
    return(flextable::set_table_properties(ft, layout = "autofit", width = 1))
  }
  flextable::width(ft, width = dim(ft)$widths * pgwidth / sum(dim(ft)$widths))
}
FitFlextableToPage <- fit_flextable_to_page   # backwards-compatible alias

#' Significance stars. Home-made because the default gtools cutpoints round
#' 0.05 downwards. Uses stats::symnum, so gtools is not needed.
stars_pval <- function(p.value) {
  unclass(stats::symnum(p.value, corr = FALSE, na = FALSE,
                        cutpoints = c(0, 0.0010001, 0.010001, 0.050001, 1),
                        symbols   = c("***", "**", "*", " ")))
}
stars.pval <- stars_pval   # backwards-compatible alias

# --- Figure typography (points) --------------------------------------------
text.size       <- 8
text.size.small <- 6
title.size      <- 9
line.size       <- 0.3
line.size.thin  <- 0.1
strip.text.size <- 8

# --- Palette ---------------------------------------------------------------
# Hues 190/210/230 (blue-green) and 5/20/50 (warm).
# RGB base 299191, generated at paletton.com
color4 <- "#35669D"; color5 <- "#299191"; color6 <- "#30AC66"
color1 <- "#F1AD44"; color2 <- "#F18044"; color3 <- "#F15844"
color7 <- "#BABABA"

color4.2 <- "#4E7FB6"; color5.2 <- "#41ABAB"; color6.2 <- "#4AC37F"
color1.2 <- "#FFC161"; color2.2 <- "#FF9861"; color3.2 <- "#FF7361"

color4.3 <- "#1A5596"; color5.3 <- "#0E8A8A"; color6.3 <- "#10A450"
color1.3 <- "#E69417"; color2.3 <- "#E65F17"; color3.3 <- "#E62F17"

palette1 <- c(color1)
palette2 <- c(color1, color4)
palette3 <- c(color1, color4, color7)
palette4 <- c(color1, color2, color4, color5)
palette5 <- c(color1, color2, color7, color4, color5)
palette6 <- c(color1, color2, color3, color4, color5, color6)
