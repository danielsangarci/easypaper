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
#
# The text cites with the caption's word unless a style gives one of its own:
# fig-text, tbl-text, sfig-text and stbl-text -- "Figure 1." under the figure,
# "Fig. 1" in the text. In the crossref: block they are Quarto's own keys:
# fig-prefix beside fig-title, and reference-prefix beside caption-prefix in
# the sfig and stbl types.
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
  custom <- function(key, field) {
    for (k in cr$custom) {
      if (is.list(k) && identical(k$key, key)) return(pick(k[[field]]))
    }
    NULL
  }
  # The word of the text, only where it differs from the caption's.
  apart <- function(text, caption) {
    if (!is.null(text) && !is.null(caption) && !identical(text, caption)) text
  }
  fig  <- pick(cr[["fig-title"]]) %or% pick(cr[["fig-prefix"]])
  tbl  <- pick(cr[["tbl-title"]]) %or% pick(cr[["tbl-prefix"]])
  sfig <- custom("sfig", "caption-prefix") %or% custom("sfig", "reference-prefix")
  stbl <- custom("stbl", "caption-prefix") %or% custom("stbl", "reference-prefix")
  s <- list(fig   = fig, tbl = tbl, sfig = sfig, stbl = stbl,
            `fig-text`  = apart(pick(cr[["fig-prefix"]]), fig),
            `tbl-text`  = apart(pick(cr[["tbl-prefix"]]), tbl),
            `sfig-text` = apart(custom("sfig", "reference-prefix"), sfig),
            `stbl-text` = apart(custom("stbl", "reference-prefix"), stbl),
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

  # The caption's word, and the text's: the same unless the style says.
  text <- function(kind) s[[paste0(kind, "-text")]] %or% s[[kind]]
  cr[["fig-title"]]   <- s$fig
  cr[["tbl-title"]]   <- s$tbl
  cr[["fig-prefix"]]  <- text("fig")
  cr[["tbl-prefix"]]  <- text("tbl")
  cr[["title-delim"]] <- .delim_md(s$delim)

  # The custom supplementary types follow the same style, with the caption's
  # word in both of Quarto's fields. Quarto 1.9 swaps caption-prefix and
  # reference-prefix in a .docx and an .html -- "Fig. S1: caption", "see
  # Figure S1" -- so the text's word, when it differs, is written by
  # easypaper itself, citation by citation (.suppl_text_word()).
  if (!is.null(cr$custom)) {
    cr$custom <- lapply(cr$custom, function(k) {
      for (kind in c("sfig", "stbl")) {
        if (identical(k$key, kind)) {
          k[["caption-prefix"]]   <- s[[kind]]
          k[["reference-prefix"]] <- s[[kind]]
        }
      }
      k
    })
  }
  cr
}

#' The word the text cites the supplementary floats with, for each kind --
#' the caption's unless the style gives one of its own -- and whether it
#' differs from the caption's, in which case every citation of them is
#' written by easypaper, in every document.
#' @noRd
.suppl_text_word <- function(style = "default") {
  s <- .caption_styles()[[style]]
  if (is.null(s)) s <- caption_styles$default
  word <- list(sfig = s[["sfig-text"]] %or% s$sfig %or% "Figure S",
               stbl = s[["stbl-text"]] %or% s$stbl %or% "Table S")
  structure(word, apart = !is.null(s[["sfig-text"]]) || !is.null(s[["stbl-text"]]))
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
#' delimiter of the style -- LaTeX ignores `title-delim` and writes
#' "Figure 1:" whatever it says, and the caption package, which Quarto loads,
#' takes a separator of its own -- and justified, a short one too: LaTeX
#' centres a caption that fits on one line, and justifies the others.
#' @noRd
.pdf_captions <- function(b, cr) {
  delim <- cr[["title-delim"]]
  has_delim <- is.character(delim) && length(delim) == 1L && nzchar(delim)
  if (!is.list(b)) b <- list()
  tex <- if (has_delim) {
    x <- gsub("([#$%&_{}])", "\\\\\\1", delim)
    x <- gsub("\u00a0", "~", x, fixed = TRUE)
    gsub("^ +", "~", x)
  }
  .pdf_header(b, paste0(
    "\\usepackage{caption}\n",
    if (has_delim) paste0("\\DeclareCaptionLabelSeparator{easypaper}{", tex, " }\n"),
    "\\captionsetup{", if (has_delim) "labelsep=easypaper,",
    "justification=justified,singlelinecheck=false}"))
}

#' Add a piece of LaTeX to what a pdf format block puts in the header,
#' after whatever is there.
#' @noRd
.pdf_header <- function(b, text) {
  if (!is.list(b)) b <- list()
  inc <- b[["include-in-header"]]
  if (is.list(inc) && !is.null(names(inc))) inc <- list(inc)
  b[["include-in-header"]] <- c(as.list(inc), list(list(text = text)))
  b
}

#' The Greek letters, as the PDF can print them. Latin Modern, LaTeX's font,
#' has none: a beta typed in the text, or written by inline R, came out as a
#' blank box. Each is taken from the maths font, which has them, so nothing
#' has to be installed.
#' @noRd
GREEK_TEX <- c(
  "\u03b1" = "\\alpha", "\u03b2" = "\\beta", "\u03b3" = "\\gamma",
  "\u03b4" = "\\delta", "\u03b5" = "\\varepsilon", "\u03b6" = "\\zeta",
  "\u03b7" = "\\eta", "\u03b8" = "\\theta", "\u03b9" = "\\iota",
  "\u03ba" = "\\kappa", "\u03bb" = "\\lambda", "\u03bc" = "\\mu",
  "\u03bd" = "\\nu", "\u03be" = "\\xi", "\u03bf" = "o",
  "\u03c0" = "\\pi", "\u03c1" = "\\rho", "\u03c2" = "\\varsigma",
  "\u03c3" = "\\sigma", "\u03c4" = "\\tau", "\u03c5" = "\\upsilon",
  "\u03c6" = "\\phi", "\u03c7" = "\\chi", "\u03c8" = "\\psi",
  "\u03c9" = "\\omega", "\u03d1" = "\\vartheta", "\u03d5" = "\\phi",
  "\u03f5" = "\\epsilon",
  "\u0391" = "\\mathrm{A}", "\u0392" = "\\mathrm{B}", "\u0393" = "\\Gamma",
  "\u0394" = "\\Delta", "\u0395" = "\\mathrm{E}", "\u0396" = "\\mathrm{Z}",
  "\u0397" = "\\mathrm{H}", "\u0398" = "\\Theta", "\u0399" = "\\mathrm{I}",
  "\u039a" = "\\mathrm{K}", "\u039b" = "\\Lambda", "\u039c" = "\\mathrm{M}",
  "\u039d" = "\\mathrm{N}", "\u039e" = "\\Xi", "\u039f" = "\\mathrm{O}",
  "\u03a0" = "\\Pi", "\u03a1" = "\\mathrm{P}", "\u03a3" = "\\Sigma",
  "\u03a4" = "\\mathrm{T}", "\u03a5" = "\\Upsilon", "\u03a6" = "\\Phi",
  "\u03a7" = "\\mathrm{X}", "\u03a8" = "\\Psi", "\u03a9" = "\\Omega")

#' The house style of every PDF, beyond its captions: the Greek letters
#' printed, and the title block -- the title, its subtitle and the authors --
#' set flush left, as a paper is, instead of LaTeX's centred one; the title
#' large and not bold, as the Word templates set it.
#' @noRd
.pdf_house <- function(b) {
  .pdf_header(b, paste0(
    "\\usepackage{newunicodechar}\n",
    paste0("\\newunicodechar{", names(GREEK_TEX), "}{\\ensuremath{", GREEK_TEX, "}}",
           collapse = "\n"), "\n",
    # Quarto appends a subtitle to the title, in the title's own font. Held
    # apart instead -- this is read before Quarto defines \subtitle, which
    # it only provides -- it comes out under the title, at 13 pt: a point
    # under the Word supplement's 14, as the text of the PDF, 11 pt, is a
    # point under Word's. The reference of the paper under "Supporting
    # Information".
    # The ORCID iD beside each name that has one, linked to the record: the
    # icon drawn here, in its green, so nothing has to be installed for it.
    "\\usepackage{tikz}\n",
    "\\definecolor{easypaperorcid}{HTML}{A6CE39}\n",
    "\\newcommand{\\easypaperorcid}[1]{\\href{https://orcid.org/#1}{\\raisebox{-.2ex}{",
    "\\tikz{\\fill[easypaperorcid] (0,0) circle (.55em);",
    "\\node[text=white,font=\\sffamily\\bfseries\\fontsize{5}{5}\\selectfont,",
    "inner sep=0pt] at (0,0) {iD};}}}}\n",
    "\\makeatletter\n",
    "\\def\\easypaper@subtitle{}\n",
    "\\providecommand{\\subtitle}[1]{\\gdef\\easypaper@subtitle{#1}}\n",
    "\\renewcommand\\@maketitle{\\newpage\\null\\vskip 1em\n",
    "  \\begin{flushleft}{\\LARGE \\@title\\par}\n",
    "  \\ifx\\easypaper@subtitle\\@empty\\else\\vskip .8em",
    "{\\fontsize{13pt}{16pt}\\selectfont \\easypaper@subtitle\\par}\\fi\\vskip 1.2em\n",
    "  {\\large\\lineskip .5em \\@author\\par}\\end{flushleft}\\par\\vskip 1em}\n",
    "\\makeatother"))
}

#' The first that is not NULL. Base R has it only from 4.4.
#' @noRd
`%or%` <- function(a, b) if (is.null(a)) b else a
