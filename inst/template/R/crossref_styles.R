# ---------------------------------------------------------------------------
# Caption styles per journal.
#
# In Rmarkdown this was done by R/captions.R (home-made counters). In Quarto
# the numbering is native: all that is decided here is how it is WRITTEN.
#
#   default -> Figure 1. txt   |  abbrev  -> Fig. 1. txt
#   nature  -> Figure 1 | txt  |  compact -> F1: txt
#
# make.R injects the resulting block with quarto_render(metadata = ...), so
# switching journal is an argument and no .qmd is touched.
# Add here the style of every journal you submit to.
# ---------------------------------------------------------------------------

caption_styles <- list(
  default = list(fig = "Figure", tbl = "Table",
                 sfig = "Figure S", stbl = "Table S",
                 delim = ".",  space = TRUE),
  abbrev  = list(fig = "Fig.",   tbl = "Table",
                 sfig = "Fig. S", stbl = "Table S",
                 delim = ".",  space = TRUE),
  nature  = list(fig = "Figure", tbl = "Table",
                 sfig = "Figure S", stbl = "Table S",
                 delim = " |", space = TRUE),
  compact = list(fig = "F",      tbl = "T",
                 sfig = "FS",    stbl = "TS",
                 delim = ":",  space = FALSE)
)

#' Complete crossref block to pass to quarto_render(metadata =).
#'
#' It starts from the crossref: block of _quarto.yml (where the custom sfig and
#' stbl types come from) and overwrites only the prefixes and the delimiter.
#' The whole block is passed so the result does not depend on how Quarto merges
#' partial metadata.
crossref_metadata <- function(style = "default",
                              quarto_yml = here::here("_quarto.yml")) {
  s <- caption_styles[[style]]
  if (is.null(s)) {
    stop("Unknown caption style: '", style, "'. Available: ",
         paste(names(caption_styles), collapse = ", "), call. = FALSE)
  }

  cr <- yaml::read_yaml(quarto_yml)$crossref
  if (is.null(cr)) cr <- list()

  cr[["fig-title"]]   <- s$fig
  cr[["tbl-title"]]   <- s$tbl
  cr[["fig-prefix"]]  <- s$fig
  cr[["tbl-prefix"]]  <- s$tbl
  cr[["title-delim"]] <- s$delim
  if (!isTRUE(s$space)) cr[["space-before-numbering"]] <- FALSE

  # The custom supplementary types follow the same style.
  if (!is.null(cr$custom)) {
    cr$custom <- lapply(cr$custom, function(k) {
      if (identical(k$key, "sfig")) k[["reference-prefix"]] <- s$sfig
      if (identical(k$key, "stbl")) k[["reference-prefix"]] <- s$stbl
      k
    })
  }
  cr
}
