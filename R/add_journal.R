# The official repository, one file per style, served raw by GitHub.
.csl_repo <- "https://raw.githubusercontent.com/citation-style-language/styles/master"

#' Add a journal's citation style to the project
#'
#' The template ships one `.csl`, `journal-of-ecology.csl`, as an example.
#' This fetches any other from the official CSL repository -- a couple of
#' thousand styles, one per journal or publisher -- and puts it in the
#' project's `references/` folder, beside the `.bib`, where
#' `render_docx("<journal>")` and `make_submission("<journal>")` look for it.
#'
#' Give the name the repository uses: the file name without `.csl`, lower case
#' with hyphens, as in `"nature"`, `"plos-one"`, `"apa"` or
#' `"journal-of-ecology"`. The list is at
#' <https://github.com/citation-style-language/styles>, and Zotero's style
#' finder at <https://www.zotero.org/styles> searches it by journal name; its
#' URLs work here too.
#'
#' Most journals have a *dependent* style: a few lines of metadata pointing at
#' the parent whose rules they share. Pandoc cannot follow that pointer, so the
#' parent's rules are fetched and saved under the name you asked for, and the
#' message says which parent it was.
#'
#' Nothing new is installed: base R downloads the file, and it is checked to
#' be a CSL style before it is kept.
#'
#' @param journal The style's name in the repository, with or without `.csl`,
#'   or the URL of a `.csl` file.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @param overwrite Replace a style the project already has. `FALSE` (the
#'   default) leaves it and says so.
#' @param repo Where to fetch from: the official repository by default.
#'   Another URL, or the path of a local checkout of the repository, to work
#'   offline or behind a mirror.
#' @return The path of the `.csl` written, invisibly.
#' @seealso [list_journals()] for the styles a project has.
#' @export
#' @examples
#' # Offline, from a local copy of the repository. Here the copy is a folder
#' # holding a single style, the one every project ships.
#' dir  <- file.path(tempdir(), "my_paper")
#' repo <- file.path(tempdir(), "styles")
#' create_paper(dir, git = FALSE)
#' dir.create(repo, showWarnings = FALSE)
#' file.copy(file.path(dir, "references", "journal-of-ecology.csl"),
#'           file.path(repo, "my-journal.csl"))
#' add_journal("my-journal", path = dir, repo = repo)
#' list_journals(dir)
#' unlink(c(dir, repo), recursive = TRUE)
#'
#' \dontrun{
#' # The usual way, from the root of a project. Needs a connection.
#' add_journal("ecology-letters")     # then: render_docx("ecology-letters")
#' add_journal("plos-one")
#' add_journal("https://www.zotero.org/styles/nature")
#' }
add_journal <- function(journal, path = ".", overwrite = FALSE, repo = NULL) {
  .check_string(journal, "journal")
  .check_string(path, "path")
  .check_flag(overwrite, "overwrite")
  if (is.null(repo)) repo <- .csl_repo else .check_string(repo, "repo")
  .enter_project(path)
  styles <- .p("references")
  if (!dir.exists(styles)) dir.create(styles, recursive = TRUE)

  is_url <- grepl("^https?://", journal)
  name <- sub("[.]csl$", "", basename(trimws(journal)))
  if (!is_url) name <- tolower(name)
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", name)) {
    stop("`journal` should be a style name such as \"plos-one\" -- lower ",
         "case, hyphens, no spaces -- or the URL of a .csl file.",
         call. = FALSE)
  }
  dest <- file.path(styles, paste0(name, ".csl"))
  have <- tryCatch(.csl_path(name), error = function(e) NULL)
  if (!is.null(have) && !overwrite) {
    message(name, ".csl is already in the project. overwrite = TRUE fetches ",
            "it again.")
    return(invisible(have))
  }

  # Independent styles sit at the root of the repository, dependent ones in
  # dependent/. A URL is taken as it is.
  csl <- if (is_url) {
    .csl_fetch(journal)
  } else {
    .or(.csl_fetch(repo, paste0(name, ".csl")),
        .csl_fetch(repo, paste0("dependent/", name, ".csl")))
  }
  if (is.null(csl)) {
    stop("No style called '", name, "' at ", if (is_url) journal else repo, ".",
         if (!is_url) paste0(
           " The names are the file names of ",
           "https://github.com/citation-style-language/styles without .csl; ",
           "Zotero's style finder at https://www.zotero.org/styles searches ",
           "them by journal."),
         call. = FALSE)
  }

  parent <- .csl_parent(csl)
  if (!is.na(parent)) {
    pname <- sub("[.]csl$", "", basename(parent))
    pcsl  <- if (is_url) {
      .or(.csl_fetch(parent), .csl_fetch(paste0(parent, ".csl")))
    } else {
      .csl_fetch(repo, paste0(pname, ".csl"))
    }
    if (is.null(pcsl) || !is.na(.csl_parent(pcsl))) {
      stop("'", name, "' is a dependent style, and its parent '", pname,
           "' could not be fetched.", call. = FALSE)
    }
    # The parent's rules, under the journal's own title: the title is what
    # names the journal in the submission folder and the cover letter.
    csl <- .csl_retitle(pcsl, csl, pname)
  }
  writeLines(csl, dest, useBytes = TRUE)

  title <- .csl_title(csl)
  message("Added references/", name, ".csl",
          if (is.na(title)) "" else paste0(" (", title, ")"),
          if (is.na(parent)) "" else paste0(
            ": a dependent style, so what was saved are the rules of its ",
            "parent, '", pname, "'"),
          ".\n  render_docx(\"", name, "\") and make_submission(\"", name,
          "\") now use it.")
  invisible(dest)
}

# --- Helpers ---------------------------------------------------------------

#' The first that is not NULL; the second is only evaluated if needed.
#' @noRd
.or <- function(a, b) if (is.null(a)) b else a

#' The lines of a .csl, from a repository URL, a local checkout, or a direct
#' URL; NULL when it is not there or is not a style. Never throws: a missing
#' file is an answer, not an error.
#' @noRd
.csl_fetch <- function(base, rel = NULL) {
  if (dir.exists(base)) {
    f <- if (is.null(rel)) base else file.path(base, rel)
    if (!file.exists(f) || dir.exists(f)) return(NULL)
  } else {
    url <- if (is.null(rel)) base else paste(sub("/+$", "", base), rel, sep = "/")
    f <- tempfile(fileext = ".csl")
    on.exit(unlink(f), add = TRUE)
    status <- suppressWarnings(tryCatch(
      utils::download.file(url, f, quiet = TRUE, mode = "wb"),
      error = function(e) 1L))
    if (!identical(status, 0L) || !file.exists(f)) return(NULL)
  }
  txt <- readLines(f, warn = FALSE, encoding = "UTF-8")
  if (!.csl_is_style(txt)) return(NULL)
  txt
}

#' A CSL style declares itself in its root element. An HTML error page, or a
#' file that is something else with the right extension, does not.
#' @noRd
.csl_is_style <- function(txt) {
  head <- paste(utils::head(txt, 30), collapse = " ")
  grepl("<style", head, fixed = TRUE) &&
    grepl("purl.org/net/xbiblio/csl", head, fixed = TRUE)
}

#' The href of a dependent style's parent, or NA for an independent one.
#' @noRd
.csl_parent <- function(txt) {
  one  <- paste(txt, collapse = " ")
  link <- regmatches(one, regexpr("<link[^>]*rel=\"independent-parent\"[^>]*>", one))
  if (!length(link)) return(NA_character_)
  href <- regmatches(link, regexpr("href=\"[^\"]+\"", link))
  if (!length(href)) return(NA_character_)
  sub("\"$", "", sub("^href=\"", "", href))
}

#' The parent's style, with the title of the dependent style that points at
#' it, and a comment saying so. Only the title changes: the rules are the
#' parent's, which is the point.
#' @noRd
.csl_retitle <- function(parent, dependent, pname) {
  one <- paste(dependent, collapse = " ")
  t <- regmatches(one, regexpr("<title>[^<]*</title>", one))
  i <- grep("<title>[^<]*</title>", parent)[1]
  if (!length(t) || is.na(i)) return(parent)
  parent[i] <- sub("<title>[^<]*</title>", t, parent[i])
  # The parent's short title would still name the parent.
  parent <- parent[!grepl("<title-short>", parent, fixed = TRUE)]
  note <- sprintf(paste0("  <!-- The rules of the '%s' style, under the name ",
                         "of the journal that uses them. -->"), pname)
  j <- grep("<info>", parent, fixed = TRUE)[1]
  if (!is.na(j)) parent <- append(parent, note, after = j - 1L)
  parent
}

#' The style's own title, for the message; NA when it has none.
#' @noRd
.csl_title <- function(txt) {
  one <- paste(txt, collapse = " ")
  t <- regmatches(one, regexpr("<title>[^<]*</title>", one))
  if (!length(t)) return(NA_character_)
  t <- trimws(gsub("<[^>]+>", "", t))
  t <- gsub("&amp;", "&", t, fixed = TRUE)
  if (nzchar(t)) t else NA_character_
}
