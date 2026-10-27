# ---------------------------------------------------------------------------
# The project a function works on.
#
# Every function that builds a manuscript works on one project: the folder
# holding its _quarto.yml and manuscript.qmd. It is found from `path`, or
# from the folder set_paper() named, by walking up, so a call made from R/ or
# _sections/ finds it too. A function that writes never takes the working
# directory for it: CRAN's policy, a package writes only where it is told to.
# One that only reads does, when it is told nothing.
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
  start <- normalizePath(path.expand(path), winslash = "/", mustWork = FALSE)
  if (!dir.exists(start)) {
    stop("`", path, "` is not a folder.", call. = FALSE)
  }
  d <- start
  repeat {
    # normalizePath() again, the root must be the same string whichever
    # folder it was found from. Forward slashes, also on Windows: the paths
    # built on the root reach Pandoc in the metadata, which reads every
    # backslash as an escape -- C:\Users\Ana Lopez\paper came out as
    # C:Lopez, and the render did not find the .csl.
    if (.is_project(d)) return(normalizePath(d, winslash = "/"))
    up <- dirname(d)
    if (identical(up, d)) break
    d <- up
  }
  stop("No easypaper project at `", start, "` or in any folder above it. A ",
       "project is the folder holding _quarto.yml and manuscript.qmd: open its ",
       ".Rproj, or pass its folder as `path`.", call. = FALSE)
}

#' A path with forward slashes, the only ones Pandoc's metadata takes as they
#' are: a backslash there is an escape. Windows reads both.
#' @noRd
.slashes <- function(x) gsub("\\", "/", x, fixed = TRUE)

#' @noRd
.is_project <- function(d) {
  file.exists(file.path(d, "_quarto.yml")) &&
    file.exists(file.path(d, "manuscript.qmd"))
}

#' Make `path`'s project the one every helper reads, until the calling
#' function returns.
#'
#' `path = NULL`, every function's default, is the project set_paper() named.
#' With none named, a function that writes -- `writes = TRUE` -- stops before
#' writing anything, and one that only reads takes the project the working
#' directory is in. A nested call with no path of its own stays in its
#' caller's project.
#'
#' The reset is registered in the caller's frame, the way withr::defer() does
#' it, so the exported function needs one line and no on.exit() of its own.
#' @noRd
.enter_project <- function(path = NULL, envir = parent.frame(), writes = TRUE) {
  old <- .ep$root
  root <- if (!is.null(path)) {
    .find_root(path)
  } else if (!is.null(old)) {
    old
  } else if (!is.null(.ep$paper)) {
    # Found again each time: the folder may have gone since it was named.
    .find_root(.ep$paper)
  } else if (writes) {
    .no_paper(.caller_name(sys.call(-1)))
  } else {
    .find_root(".")
  }
  .ep$root <- root
  do.call(base::on.exit, list(bquote(.ep$root <- .(old)), add = TRUE),
          envir = envir)
  # The outermost call: what it has said once, its nested calls do not say
  # again (.say_once()), and the next call says it afresh.
  if (is.null(old)) {
    do.call(base::on.exit, list(quote(.ep$said <- NULL), add = TRUE),
            envir = envir)
  }
  invisible(root)
}

#' Stop a function that would write with no project named: easypaper never
#' takes the working directory for the place to write.
#' @noRd
.no_paper <- function(fn = "this function") {
  stop(fn, "() writes into a project, and none is named.\n",
       "  Name it once a session, from the project's folder: set_paper(\".\")\n",
       "  or in this call: ", fn, "(path = \".\")", call. = FALSE)
}

#' Name the paper to work on
#'
#' The functions that write into a project -- the renders, the submissions,
#' [convert_data()] and the rest -- write into the one you name: here, once a
#' session, or with `path` in each call. easypaper never takes the working
#' directory for it: with neither, a function that writes stops before
#' writing anything. The functions that only read, such as
#' [check_citations()] or [manuscript_stats()], use the project named here
#' too, and otherwise the one the working directory is in.
#'
#' Once the project's `.Rproj` is open, the working directory is its root, so
#' `set_paper(".")` names it. The project stays named until the session ends
#' or you name another; `path` in a call works on that project for that call
#' alone.
#'
#' @param path The project, or any folder inside it: `"."` from the project's
#'   folder. `NULL` forgets the one named, and then nothing is written until a
#'   project is named again.
#' @return The project named before, invisibly -- `NULL` if none was -- so
#'   that it can be put back.
#' @seealso [get_paper()], which says which project is named, and
#'   [create_paper()], which makes one.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' old <- set_paper(dir)
#' get_paper()
#' list_journals()
#' set_paper(old)
#' unlink(dir, recursive = TRUE)
set_paper <- function(path) {
  if (missing(path)) {
    stop("`path` is missing: give the project's folder, e.g. set_paper(\".\") ",
         "from it.", call. = FALSE)
  }
  old <- .ep$paper
  if (is.null(path)) {
    .ep$paper <- NULL
    return(invisible(old))
  }
  .ep$paper <- .find_root(path)
  message("Working on ", .ep$paper)
  invisible(old)
}

#' Which paper is named
#'
#' The project [set_paper()] named for this session: the one every function
#' works on when it is given no `path`.
#'
#' @return The project's root, or `NULL` when none is named; printed in a
#'   sentence when called from the console, and returned invisibly then.
#' @seealso [set_paper()]
#' @export
#' @examples
#' get_paper()   # NULL: none named yet
#'
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' old <- set_paper(dir)
#' get_paper()
#' set_paper(old)
#' unlink(dir, recursive = TRUE)
get_paper <- function() {
  root <- .ep$paper
  if (is.null(root)) {
    message("No project is named. Name it once a session, from its folder: ",
            "set_paper(\".\")")
  } else {
    message("Working on ", root)
  }
  invisible(root)
}

#' The name of the exported function a call is, for a message: "render_html"
#' whether it was called as render_html() or easypaper::render_html().
#' @noRd
.caller_name <- function(cl) {
  f <- tryCatch(cl[[1]], error = function(e) NULL)
  if (is.null(f)) return("this function")
  sub("^.*::", "", paste(deparse(f), collapse = ""))
}

#' Say something once a call. render_all() and the make_*() run several
#' renders, and each checks the same things: what one of them has said, the
#' others do not say again. Outside a project call it is said every time.
#' @noRd
.say_once <- function(key, ...) {
  if (key %in% .ep$said) return(invisible(FALSE))
  if (!is.null(.ep$root)) .ep$said <- union(.ep$said, key)
  message(...)
  invisible(TRUE)
}

#' The name of the project: its folder, as the .Rproj is named. Read at the
#' moment of asking, so a folder renamed later names what is rendered after.
#' Made safe for a file name.
#' @noRd
.project_name <- function() {
  gsub("[^A-Za-z0-9._-]+", "_", basename(.p()))
}

#' The name a render gives a document in output/: `manuscript_<project>`,
#' `supporting_information_<project>` -- then the part of a supplement
#' among several, and the journal when it is not the manuscript's own, so
#' trying the style of another journal leaves yours as it was.
#' @noRd
.output_name <- function(what, journal, ext, part = NULL) {
  own <- tryCatch(.resolve_journal(NULL), error = function(e) NULL)
  other <- if (!is.null(journal) && !identical(journal, own)) journal
  paste0(paste(c(what, .project_name(), part, other), collapse = "_"), ".", ext)
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
#' @param path The project, or any folder inside it. Left out, the one
#'   [set_paper()] named, or else the project the working directory is in:
#'   this only reads.
#' @return A character vector of journal names, sorted.
#' @seealso [add_journal()], and the `journal` argument of [render_docx()] and
#'   [make_submission()].
#' @export
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, git = FALSE)
#' list_journals(dir)
#' unlink(dir, recursive = TRUE)
list_journals <- function(path = NULL) {
  .enter_project(path, writes = FALSE)
  f <- unlist(lapply(.csl_dirs(), list.files, pattern = "[.]csl$"))
  sort(unique(sub("[.]csl$", "", f)))
}

#' The .csl file of a journal, or stop listing the ones there are.
#' @noRd
.csl_path <- function(journal) {
  for (d in .csl_dirs()) {
    f <- file.path(d, paste0(journal, ".csl"))
    if (file.exists(f)) return(.slashes(f))
  }
  # The manuscript may name a style kept somewhere else altogether.
  declared <- .declared_csl()
  if (!is.null(declared) &&
      identical(sub("[.]csl$", "", basename(declared)), journal)) {
    f <- if (grepl("^(/|~|[A-Za-z]:)", declared)) path.expand(declared)
         else .p(declared)
    if (file.exists(f)) return(.slashes(f))
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

#' Where render_supplementary() writes, until the calling function returns.
#' output/, unless a deliverable gives its own folder: make_submission() and
#' make_preprint() render the supplement for what they send -- blinded, with
#' their own line spacing -- and it must not replace the one in output/.
#' @noRd
.set_suppl_dir <- function(dir, envir = parent.frame()) {
  old <- .ep$suppl_dir
  .ep$suppl_dir <- dir
  do.call(base::on.exit, list(bquote(.ep$suppl_dir <- .(old)), add = TRUE),
          envir = envir)
  invisible(old)
}

#' The resolution a deliverable draws its figures at, until the calling
#' function returns: make_submission(figure_dpi =). NULL leaves it to the
#' `dpi` of _quarto.yml.
#' @noRd
.set_dpi <- function(dpi, envir = parent.frame()) {
  old <- .ep$dpi
  .ep$dpi <- dpi
  do.call(base::on.exit, list(bquote(.ep$dpi <- .(old)), add = TRUE),
          envir = envir)
  invisible(old)
}

#' Where the paper is, for the reference the supplement opens with, until the
#' calling function returns: a journal unless a deliverable says otherwise --
#' make_preprint(), whose paper is in no journal yet.
#' @noRd
.set_venue <- function(venue, envir = parent.frame()) {
  old <- .ep$venue
  .ep$venue <- venue
  do.call(base::on.exit, list(bquote(.ep$venue <- .(old)), add = TRUE),
          envir = envir)
  invisible(old)
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
