# ---------------------------------------------------------------------------
# The project a function works on.
#
# Every function that builds a manuscript works on one project: the folder
# holding its _quarto.yml and manuscript.qmd. It is found from `path` -- the
# working directory by default, which is the project root once its .Rproj is
# open -- by walking up, so a call made from R/ or _sections/ finds it too.
#
# Nested calls share it. render_docx() calls render_supplementary(), which
# calls .bibliography(), and none of them passes the root along:
# .enter_project() sets it for as long as the outermost exported call runs,
# and puts back whatever was there before when that call ends, error or not.
# A nested call that was not given a path of its own keeps the one in force,
# so render_docx(path = "~/paper") renders the supplement of that same paper
# and not of whatever the working directory happens to be.
# ---------------------------------------------------------------------------

.ep <- new.env(parent = emptyenv())

#' The root of the project at or above `path`, or stop saying what is missing.
#' @noRd
.find_root <- function(path = ".") {
  .check_string(path, "path")
  start <- normalizePath(path.expand(path), mustWork = FALSE)
  if (!dir.exists(start)) {
    stop("`", path, "` is not a folder.", call. = FALSE)
  }
  d <- start
  repeat {
    # normalizePath() again: on Windows dirname() rewrites "\\" to "/", and
    # the root must be the same string whichever folder it was found from.
    if (.is_project(d)) return(normalizePath(d))
    up <- dirname(d)
    if (identical(up, d)) break
    d <- up
  }
  stop("No easypaper project at `", start, "` or in any folder above it. A ",
       "project is the folder holding _quarto.yml and manuscript.qmd: open its ",
       ".Rproj, or pass its folder as `path`.", call. = FALSE)
}

#' @noRd
.is_project <- function(d) {
  file.exists(file.path(d, "_quarto.yml")) &&
    file.exists(file.path(d, "manuscript.qmd"))
}

#' Make `path`'s project the one every helper reads, until the calling
#' function returns.
#'
#' The reset is registered in the caller's frame, the way withr::defer() does
#' it, so the exported function needs one line and no on.exit() of its own.
#' @noRd
.enter_project <- function(path = ".", envir = parent.frame()) {
  old <- .ep$root
  # Called from inside another call on the same project, with no path of its
  # own: stay where we are.
  root <- if (!is.null(old) && identical(path, ".")) old else .find_root(path)
  .ep$root <- root
  do.call(base::on.exit, list(bquote(.ep$root <- .(old)), add = TRUE),
          envir = envir)
  invisible(root)
}

#' A path inside the current project.
#' @noRd
.p <- function(...) {
  root <- .ep$root
  if (is.null(root)) {
    stop("Internal error: no project is set. Please report this at ",
         "https://github.com/danielsangarci/easypaper/issues", call. = FALSE)
  }
  file.path(root, ...)
}

#' The manuscript's master file.
#' @noRd
.master <- function() .p("manuscript.qmd")

# --- The project's own settings --------------------------------------------

#' What `_quarto.yml` says under `easypaper:`. Quarto ignores the block, and
#' it travels with the project, so a setting made once holds on every
#' computer the paper is rendered on.
#' @noRd
.config <- function(key, default = NULL) {
  y <- tryCatch(yaml::read_yaml(.p("_quarto.yml"))$easypaper,
                error = function(e) NULL)
  v <- if (is.list(y)) y[[key]] else NULL
  if (is.null(v)) default else v
}

# --- Word templates ---------------------------------------------------------

#' The Word template a document is written on.
#'
#' They ship with the package, in inst/word/. A project that wants its own
#' puts a file of the same name in a `format/` folder of its own, and that
#' one wins.
#' @noRd
.word_template <- function(which = c("manuscript", "supplement", "letter")) {
  which <- match.arg(which)
  f <- c(manuscript = "word_plain_paper_style.docx",
         supplement = "word_plain_paper_style_supplementary_material.docx",
         letter     = "word_cover_letter.docx")[[which]]
  own <- .p("format", f)
  if (file.exists(own)) return(own)
  shipped <- system.file("word", f, package = "easypaper")
  if (!nzchar(shipped)) {
    stop("The Word template ", f, " is missing from the installed package.",
         call. = FALSE)
  }
  shipped
}

# --- Citation styles ----------------------------------------------------------

#' Where a project keeps its .csl files: references/, beside the .bib.
#' @noRd
.csl_dirs <- function() {
  d <- .p("references")
  d[dir.exists(d)]
}

#' The journals a project can render for
#'
#' Every `.csl` in the project's `references/` folder, by the name the other
#' functions take: the file name without `.csl`. [add_journal()] fetches any
#' other journal's style.
#'
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return A character vector of journal names, sorted.
#' @seealso [add_journal()], and the `journal` argument of [render_docx()] and
#'   [make_submission()].
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' list_journals(dir)
#' unlink(dir, recursive = TRUE)
list_journals <- function(path = ".") {
  .enter_project(path)
  f <- unlist(lapply(.csl_dirs(), list.files, pattern = "[.]csl$"))
  sort(unique(sub("[.]csl$", "", f)))
}

#' The .csl file of a journal, or stop listing the ones there are.
#' @noRd
.csl_path <- function(journal) {
  for (d in .csl_dirs()) {
    f <- file.path(d, paste0(journal, ".csl"))
    if (file.exists(f)) return(f)
  }
  # The manuscript may name a style kept somewhere else altogether.
  declared <- .declared_csl()
  if (!is.null(declared) &&
      identical(sub("[.]csl$", "", basename(declared)), journal)) {
    f <- if (grepl("^(/|~|[A-Za-z]:)", declared)) path.expand(declared)
         else .p(declared)
    if (file.exists(f)) return(f)
  }
  have <- list_journals()
  stop("There is no citation style called '", journal, "' in references/. ",
       if (length(have)) paste0("Available: ", paste(have, collapse = ", "),
                                ". ") else "",
       "add_journal(\"", journal, "\") fetches it.", call. = FALSE)
}

#' The `csl:` the manuscript declares -- or, failing that, the one of
#' _quarto.yml, which Quarto gives every document of the project. NULL when
#' neither does.
#' @noRd
.declared_csl <- function() {
  ok <- function(x) !is.null(x) && length(x) && nzchar(as.character(x)[1])
  csl <- tryCatch(rmarkdown::yaml_front_matter(.master())$csl,
                  error = function(e) NULL)
  if (!ok(csl)) {
    csl <- tryCatch(yaml::read_yaml(.p("_quarto.yml"))$csl,
                    error = function(e) NULL)
  }
  if (ok(csl)) as.character(csl)[1] else NULL
}

#' Which journal to use: the one you asked for, or the project's own.
#'
#' The manuscript declares a `csl:` in its YAML, beside its title and its
#' authors, and that is where it says which journal it is going to. Naming
#' `journal` in a call overrides it, for that call only. The order is
#' Quarto's own: the document beats the project, so a render from the
#' RStudio button and one of the package always agree on the journal.
#' @noRd
.resolve_journal <- function(journal = NULL) {
  if (!is.null(journal) && nzchar(journal)) return(journal)
  csl <- .declared_csl()
  if (is.null(csl)) {
    stop("No journal named, and neither manuscript.qmd nor _quarto.yml has a ",
         "`csl:` line to take one from. Either add it to the manuscript's ",
         "YAML, or name one here. Available: ",
         paste(list_journals(), collapse = ", "), call. = FALSE)
  }
  sub("[.]csl$", "", basename(csl))
}

# --- The text ----------------------------------------------------------------

#' The text files of the manuscript, in the order the master includes them.
#' Read from the {{< include >}} lines of manuscript.qmd rather than from file
#' names, so the number in the prefix can keep meaning the section of the
#' paper (4.1 and 4.2 are the two parts of Results) without driving the order.
#' @noRd
.section_files <- function() {
  l <- readLines(.master(), warn = FALSE)
  inc <- regmatches(l, regexpr("\\{\\{< *include +[^>]+? *>\\}\\}", l))
  f <- .p(trimws(gsub("^\\{\\{< *include +|>\\}\\}$", "", inc)))
  missing <- !file.exists(f)
  if (any(missing)) {
    stop("manuscript.qmd includes files that do not exist: ",
         paste(basename(f[missing]), collapse = ", "), call. = FALSE)
  }
  f
}

#' A path inside output/, with the folder created if it is not there.
#'
#' Everything a render produces lands flat in output/: the .docx, the .pdf,
#' the supplement, the code. One folder, because you open it to find a
#' document, not to navigate. It is created at the moment of writing: output/
#' is regenerable and .gitignored, so it is absent after a clone.
#' @noRd
.out <- function(...) {
  p <- .p("output", ...)
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  p
}

#' The page layout a deliverable asks of the PDFs it renders -- line numbers
#' and line spacing, for the main text and for the supplement -- until the
#' calling function returns. The renders read it from here, so neither
#' .render() nor render_supplementary() needs an argument for it.
#' @noRd
.set_layout <- function(main = NULL, suppl = NULL, envir = parent.frame()) {
  old <- .ep$layout
  .ep$layout <- list(main = main, suppl = suppl)
  do.call(base::on.exit, list(bquote(.ep$layout <- .(old)), add = TRUE),
          envir = envir)
  invisible(old)
}
