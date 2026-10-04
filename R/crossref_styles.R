# ---------------------------------------------------------------------------
# Caption styles.
#
# Quarto numbers figures and tables natively: all that is decided here is how
# the number is WRITTEN.
#
#   default -> Figure 1. txt   |  abbrev  -> Fig. 1. txt
#   colon   -> Figure 1: txt   |  compact -> Fig. 1: txt
#   nature  -> Figure 1 | txt
#
# The render hands Quarto the resulting block with quarto_render(metadata =
# ...), so switching style is an argument and no .qmd is touched. "default" is
# whatever the crossref: block of _quarto.yml says, written there once. A
# project adds styles of its own under `caption-styles:` in the easypaper:
# block of _quarto.yml, each giving only what differs from its default:
#
#   easypaper:
#     caption-styles:
#       custom: {fig: "Fig.", tbl: "Tab.", sfig: "Fig. S", stbl: "Tab. S",
#                delim: ":"}
#
# There is a space between the word and the number, always: Quarto writes
# "Figure 1", and lets only a custom type such as sfig drop it ("Figure S1").
# ---------------------------------------------------------------------------

caption_styles <- list(
  default = list(fig = "Figure", tbl = "Table",
                 sfig = "Figure S", stbl = "Table S", delim = "."),
  abbrev  = list(fig = "Fig.",   tbl = "Table",
                 sfig = "Fig. S", stbl = "Table S", delim = "."),
  colon   = list(fig = "Figure", tbl = "Table",
                 sfig = "Figure S", stbl = "Table S", delim = ":"),
  compact = list(fig = "Fig.",   tbl = "Table",
                 sfig = "Fig. S", stbl = "Table S", delim = ":"),
  nature  = list(fig = "Figure", tbl = "Table",
                 sfig = "Figure S", stbl = "Table S", delim = " |")
)

#' The styles a project can use: the built-in ones, and its own, which win.
#' A style of the project's may give only what differs from `default`.
#' @noRd
.caption_styles <- function() {
  own <- .config("caption-styles", list())
  if (!is.list(own)) own <- list()
  styles <- caption_styles
  # "default" is what the crossref: block of _quarto.yml says: written once,
  # there, where preview() and Quarto read it too, and every render follows
  # it unless caption_style names another style.
  cr <- tryCatch(yaml::read_yaml(.p("_quarto.yml"))$crossref,
                 error = function(e) NULL)
  if (is.list(cr)) {
    styles$default <- utils::modifyList(styles$default, .style_of(cr))
  }
  for (nm in names(own)) {
    if (!is.list(own[[nm]])) next
    styles[[nm]] <- utils::modifyList(styles$default, own[[nm]])
  }
  styles
}

#' A caption style read off a crossref: block: what it sets, and nothing
#' else.
#' @noRd
.style_of <- function(cr) {
  pick <- function(x) if (is.character(x) && length(x) == 1L) x
  custom <- function(key) {
    for (k in cr$custom) {
      if (is.list(k) && identical(k$key, key)) return(pick(k[["reference-prefix"]]))
    }
    NULL
  }
  s <- list(fig   = pick(cr[["fig-title"]]) %or% pick(cr[["fig-prefix"]]),
            tbl   = pick(cr[["tbl-title"]]) %or% pick(cr[["tbl-prefix"]]),
            sfig  = custom("sfig"),
            stbl  = custom("stbl"),
            delim = pick(cr[["title-delim"]]))
  s[!vapply(s, is.null, logical(1))]
}

#' Complete crossref block to pass to quarto_render(metadata =).
#'
#' It starts from the crossref: block of _quarto.yml (where the custom sfig and
#' stbl types come from) and overwrites only the prefixes and the delimiter.
#' The whole block is passed so the result does not depend on how Quarto
#' merges partial metadata.
#' @noRd
crossref_metadata <- function(style = "default") {
  styles <- .caption_styles()
  s <- styles[[style]]
  if (is.null(s)) {
    stop("Unknown caption style: '", style, "'. Available: ",
         paste(names(styles), collapse = ", "), ". Add your own under ",
         "`caption-styles:` in the easypaper: block of _quarto.yml.",
         call. = FALSE)
  }

  cr <- yaml::read_yaml(.p("_quarto.yml"))$crossref
  if (is.null(cr)) cr <- list()

  cr[["fig-title"]]   <- s$fig
  cr[["tbl-title"]]   <- s$tbl
  cr[["fig-prefix"]]  <- s$fig
  cr[["tbl-prefix"]]  <- s$tbl
  cr[["title-delim"]] <- .delim_md(s$delim)

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

#' A delimiter as Quarto has to be handed it. Quarto reads `title-delim` as
#' markdown, which drops a leading space: " |" came out as "Figure 1| Text".
#' A non-breaking space survives, and keeps the bar beside its number too.
#' @noRd
.delim_md <- function(delim) {
  if (!is.character(delim) || length(delim) != 1L) return(delim)
  m <- regmatches(delim, regexpr("^ +", delim))
  if (!length(m)) return(delim)
  paste0(strrep("\u00a0", nchar(m)), substring(delim, nchar(m) + 1L))
}

#' A pdf format block that writes figure and table captions with the
#' delimiter of the style: LaTeX ignores `title-delim` and writes
#' "Figure 1:" whatever it says. The caption package, which Quarto loads,
#' takes a separator of its own.
#' @noRd
.pdf_captions <- function(b, cr) {
  delim <- cr[["title-delim"]]
  if (!is.character(delim) || length(delim) != 1L || !nzchar(delim)) return(b)
  if (!is.list(b)) b <- list()
  tex <- gsub("([#$%&_{}])", "\\\\\\1", delim)
  tex <- gsub("\u00a0", "~", tex, fixed = TRUE)
  tex <- gsub("^ +", "~", tex)
  inc <- b[["include-in-header"]]
  if (is.list(inc) && !is.null(names(inc))) inc <- list(inc)
  b[["include-in-header"]] <- c(as.list(inc), list(list(text = paste0(
    "\\usepackage{caption}\n",
    "\\DeclareCaptionLabelSeparator{easypaper}{", tex, " }\n",
    "\\captionsetup{labelsep=easypaper}"))))
  b
}

#' The first that is not NULL. Base R has it only from 4.4.
#' @noRd
`%or%` <- function(a, b) if (is.null(a)) b else a
