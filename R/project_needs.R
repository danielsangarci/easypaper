# The packages a project needs that nothing in easypaper calls itself.
#
# Every other import is used by the package's own functions. These three are
# used by the project's files, inside the render: R/setup.R loads flextable
# for the tables, manuscript.qmd finds R/setup.R with here, and _quarto.yml
# draws every figure with ragg. A project cannot render without them, and a
# computer that lacked one found out a minute into its first render, from
# inside Quarto -- so they are Imports, and install.packages("easypaper")
# brings them. R CMD check wants every import used somewhere in the code, and
# naming them here does that without loading any of them when easypaper is
# attached.
.project_needs <- function() {
  list(
    flextable::flextable,   # R/setup.R: the tables
    here::here,             # manuscript.qmd: source(here::here("R/setup.R"))
    ragg::agg_png           # _quarto.yml: dev: ragg_png
  )
}
