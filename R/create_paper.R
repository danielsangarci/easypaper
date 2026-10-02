#' Create a reproducible Quarto manuscript project
#'
#' Writes, into `path`, the structure of a reproducible manuscript: the
#' sections as separate `.qmd` files, the references and the journal's
#' citation style, `R/setup.R` for the analysis, and the folder for the data.
#' Nothing else: the functions that render and assemble it --
#' [render_docx()], [make_submission()] and the rest -- live in this package,
#' so the project holds only the paper.
#'
#' ```
#' manuscript.qmd       title, authors, journal, and the list of sections
#' supplementary.qmd    the supplement, as its own document
#' _quarto.yml          formats, and the settings of easypaper
#' _sections/           the text, one file per section
#' R/setup.R            seed, palette and helpers for the analysis
#' data/                the data, in open formats: what gets published
#' references/          the .bib you cite from, and the journal styles (.csl)
#' LICENSE  LICENSE-CODE  README.md  <name>.Rproj
#' ```
#'
#' The `easypaper:` block of `_quarto.yml` records the version of easypaper
#' that created the project, and every render records the one that built each
#' document in `renv.lock`, with every other package the paper used:
#' `renv::restore()` brings them back years later.
#'
#' Every argument is checked before anything is written, so a wrong call
#' stops with a message naming the argument and leaves no half-made project
#' behind.
#'
#' @param path Directory to create, as a single non-empty string; `~` is
#'   expanded. Its base name becomes the name of the `.Rproj` file. A path
#'   that exists as a file is refused.
#' @param title Manuscript title, written into the YAML of `manuscript.qmd`,
#'   the one place it lives. Quotes and backslashes are escaped for YAML, so a
#'   LaTeX fragment such as `\textit{Formica}` survives. A vector is joined
#'   with spaces. `NULL` or `""` leaves the placeholder, which every render
#'   warns about.
#' @param authors Character vector of author names, in order, or one
#'   comma-separated string, which is how the RStudio wizard sends them. The
#'   first one is marked as the corresponding author. Affiliations are not
#'   guessed: each author gets a placeholder to fill in, in the
#'   `affiliations:` of the YAML of `manuscript.qmd` (see [affiliations()]).
#'   `NULL` or an empty string leaves the template's.
#' @param overwrite Write into a directory that already has files in it.
#'   `FALSE` (the default) refuses, so an existing manuscript is never
#'   silently overwritten.
#' @param git Initialise a git repository and make the first commit. `TRUE` by
#'   default: it is local and private, costs a second, and gives the manuscript
#'   a history from its first line instead of from the day you remember to
#'   start one. It has nothing to do with GitHub, which is a later and separate
#'   decision. Needs `git` on the PATH and a configured `user.name` /
#'   `user.email`; if either is missing, the project is still created and you
#'   are told what to run.
#' @param open Open the new project in RStudio. Needs an RStudio session and
#'   the rstudioapi package; outside one, the project is created and a message
#'   says so.
#'
#' @return The absolute path of the created project, invisibly.
#'
#' @seealso [create_example_paper()] for the same project with a small study
#'   written in it, to see how each part is written; [render_html()] to see
#'   what you have, [convert_data()] to bring the data into the project's
#'   `data/` folder, and `vignette("easypaper")` for a tour of what the
#'   project can do.
#'
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir,
#'              title   = "Manuscript title here",
#'              authors = c("First Author", "Second Author"),
#'              git     = FALSE)
#' list.files(dir)
#' unlink(dir, recursive = TRUE)
#'
#' \dontrun{
#' # A real project, with its git history started for you:
#' create_paper("my_paper",
#'              title   = "Manuscript title here",
#'              authors = c("First Author", "Second Author"))
#' }
#' @export
create_paper <- function(path, title = NULL, authors = NULL,
                         overwrite = FALSE, git = TRUE, open = FALSE) {
  if (missing(path)) {
    stop("`path` is missing: give the directory to create.", call. = FALSE)
  }
  .check_string(path, "path")
  .check_flag(overwrite, "overwrite")
  .check_flag(git, "git")
  .check_flag(open, "open")
  path    <- path.expand(path)
  title   <- .clean_title(title)
  authors <- .clean_authors(authors)

  if (file.exists(path) && !dir.exists(path)) {
    stop("`", path, "` exists and is a file, not a directory.", call. = FALSE)
  }
  if (dir.exists(path) && !overwrite &&
      length(list.files(path, all.files = TRUE, no.. = TRUE))) {
    stop("`", path, "` already has files in it. Use overwrite = TRUE if you ",
         "really mean to write into it.", call. = FALSE)
  }
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(path)) {
    stop("Could not create `", path, "`.", call. = FALSE)
  }
  # Resolved once, so "." and a trailing slash give the project its real name
  # and the path returned is the one every later call can use.
  path <- normalizePath(path)
  name <- basename(path)

  .copy_template(path, name)
  .make_dirs(path)

  if (!is.null(title)) {
    # Written once, in the manuscript; the README's heading follows it.
    .set_title(file.path(path, "manuscript.qmd"), title)
    .sync_readme_title(file.path(path, "README.md"), title)
  }
  if (!is.null(authors)) {
    .set_authors(file.path(path, "manuscript.qmd"), authors)
  }

  .enter_project(path)
  .write_stamp()

  if (git) .git_init(path)

  message("Project created: ", path, "\n",
          "  1. open ", name, ".Rproj\n",
          "  2. library(easypaper)\n",
          "  3. render_html()      # see ?render for every command")

  if (open) {
    if (requireNamespace("rstudioapi", quietly = TRUE) &&
        rstudioapi::isAvailable()) {
      rstudioapi::openProject(path, newSession = TRUE)
    } else {
      message("open = TRUE needs an RStudio session and the rstudioapi ",
              "package: open ", name, ".Rproj by hand.")
    }
  }
  invisible(path)
}

# --- Argument checks -------------------------------------------------------

#' A single, non-empty, non-missing string, or stop naming the argument.
#' @noRd
.check_string <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop("`", what, "` must be a single non-empty string.", call. = FALSE)
  }
  invisible(TRUE)
}

#' TRUE or FALSE, nothing else: not NA, not "yes", not c(TRUE, TRUE).
#' @noRd
.check_flag <- function(x, what) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop("`", what, "` must be TRUE or FALSE.", call. = FALSE)
  }
  invisible(TRUE)
}

#' The RStudio project wizard passes every widget as a string, and an empty
#' box as "". Empty means "leave the placeholder"; a vector is one title typed
#' across lines.
#' @noRd
.clean_title <- function(title) {
  if (is.null(title)) return(NULL)
  if (!is.character(title)) {
    stop("`title` must be a character string, or NULL to keep the placeholder.",
         call. = FALSE)
  }
  title <- trimws(paste(title[!is.na(title)], collapse = " "))
  if (nzchar(title)) title else NULL
}

#' Authors arrive either as a vector or as one comma-separated line (the
#' wizard). Both become a vector of trimmed, non-empty names.
#' @noRd
.clean_authors <- function(authors) {
  if (is.null(authors)) return(NULL)
  if (!is.character(authors)) {
    stop("`authors` must be a character vector, or NULL to keep the ",
         "placeholders.", call. = FALSE)
  }
  authors <- unlist(strsplit(authors[!is.na(authors)], ",", fixed = TRUE))
  authors <- trimws(authors)
  authors <- authors[nzchar(authors)]
  if (length(authors)) authors else NULL
}

# --- The files -------------------------------------------------------------

#' Copy the installed template into `path` and give the two files that travel
#' renamed their real names.
#' @noRd
.copy_template <- function(path, name) {
  tpl <- .template_dir()
  ok <- file.copy(list.files(tpl, full.names = TRUE, all.files = TRUE,
                             no.. = TRUE),
                  path, recursive = TRUE, overwrite = TRUE, copy.date = TRUE)
  if (!all(ok)) {
    stop("Could not copy the template into `", path, "`.", call. = FALSE)
  }
  # .gitignore travels as `gitignore`: R CMD build drops dotfiles from inst/.
  # The .Rproj is named after the project so RStudio's recent list is readable.
  renamed <- c(
    file.rename(file.path(path, "gitignore"), file.path(path, ".gitignore")),
    file.rename(file.path(path, "Rproj.template"),
                file.path(path, paste0(name, ".Rproj"))))
  if (!all(renamed)) {
    stop("The template was copied, but `.gitignore` or the `.Rproj` could not ",
         "be named in `", path, "`.", call. = FALSE)
  }
  invisible(path)
}

#' The installed template, or stop: nothing works without it.
#' @noRd
.template_dir <- function() {
  tpl <- system.file("template", package = "easypaper")
  if (!nzchar(tpl) || !dir.exists(tpl)) {
    stop("The template is missing from the installed package.", call. = FALSE)
  }
  tpl
}

#' The folders git cannot carry empty, and the ones the renders write into.
#' @noRd
.make_dirs <- function(path) {
  kept <- "data/metadata"
  dirs <- file.path(path, c(kept, "output", "figures", "cache"))
  vapply(dirs, dir.create, logical(1), recursive = TRUE, showWarnings = FALSE)
  if (!all(dir.exists(dirs))) {
    stop("Could not create the project folders in `", path, "`.", call. = FALSE)
  }
  # A .gitkeep so the folder survives the first commit; the others are
  # regenerable and .gitignore leaves them out.
  file.create(file.path(path, kept, ".gitkeep"), showWarnings = FALSE)
  invisible(dirs)
}

# --- YAML ------------------------------------------------------------------

#' A YAML double-quoted scalar: backslashes first, then quotes, so a LaTeX
#' fragment or a quoted species name reaches Quarto as it was typed.
#' @noRd
.yaml_quote <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub('"', '\\"', x, fixed = TRUE)
  paste0('"', x, '"')
}

#' The lines of the front matter: the two `---` fences, the first at line 1.
#' NULL when the file has none.
#' @noRd
.yaml_bounds <- function(l) {
  fence <- grep("^---\\s*$", l)
  if (length(fence) < 2L || fence[1] != 1L) return(NULL)
  fence[1:2]
}

#' Replace one top-level key of the front matter, and only there: a line in
#' the body that happens to start with `title:` is prose, not metadata.
#'
#' The value may run on over indented lines (a list of authors, a folded
#' string); those go with it, up to the next top-level key or the closing
#' fence. Returns the new lines, or NULL when the key is not in the header.
#' @noRd
.replace_yaml_key <- function(l, key, new) {
  b <- .yaml_bounds(l)
  if (is.null(b) || b[2] - b[1] < 2L) return(NULL)
  inside <- seq.int(b[1] + 1L, b[2] - 1L)
  hit <- inside[grepl(paste0("^", key, ":"), l[inside])]
  if (!length(hit)) return(NULL)
  i <- hit[1]
  j <- i + 1L
  while (j < b[2] && grepl("^(\\s+\\S|\\s*$)", l[j])) j <- j + 1L
  # Blank lines before the next key were not part of the value: keep them.
  while (j - 1L > i && !nzchar(trimws(l[j - 1L]))) j <- j - 1L
  c(l[seq_len(i - 1L)], new, l[seq.int(j, length(l))])
}

#' The README's heading follows the manuscript's title while it is still the
#' template's: a heading you wrote yourself is yours, and stays.
#' @noRd
.sync_readme_title <- function(f, title) {
  if (!file.exists(f) || is.null(title) || identical(title, TEMPLATE_TITLE)) {
    return(invisible(FALSE))
  }
  l <- readLines(f, warn = FALSE)
  if (!length(l) || l[1] != paste("#", TEMPLATE_TITLE)) return(invisible(FALSE))
  l[1] <- paste("#", paste(title, collapse = " "))
  writeLines(l, f)
  invisible(TRUE)
}

#' Replace the `title:` of a .qmd front matter.
#' @noRd
.set_title <- function(f, title) {
  l <- readLines(f, warn = FALSE)
  new <- .replace_yaml_key(l, "title", paste0("title: ", .yaml_quote(title)))
  if (is.null(new)) return(invisible(FALSE))
  writeLines(new, f)
  invisible(TRUE)
}

#' Rewrite the `author:` block with these names, each pointing at an
#' affiliation of its own, and the `affiliations:` list with one placeholder
#' for each: the numbers are worked out at render time, so none is written
#' here. The first author is the corresponding one.
#' @noRd
.set_authors <- function(f, authors) {
  l <- readLines(f, warn = FALSE)
  n <- length(authors)
  ids <- paste0("aff", seq_len(n))
  block <- unlist(lapply(seq_len(n), function(i) {
    c(paste0("  - name: ", .yaml_quote(authors[i])),
      paste0("    affiliations: [", ids[i], "]"),
      if (i == 1L) c("    email: correspondent@example.org",
                     "    corresponding: true"))
  }))
  new <- .replace_yaml_key(l, "author", c("author:", block))
  if (is.null(new)) return(invisible(FALSE))
  aff <- c("affiliations:", unlist(lapply(seq_len(n), function(i) {
    c(paste0("  - id: ", ids[i]),
      paste0("    name: Institution ", i, ", Department, City, Country"))
  })))
  with_aff <- .replace_yaml_key(new, "affiliations", aff)
  if (is.null(with_aff)) {
    # A manuscript with no list of affiliations yet: it goes under the authors.
    i <- grep("^author:", new)[1]
    j <- i + 1L
    while (j <= length(new) && grepl("^\\s+\\S", new[j])) j <- j + 1L
    with_aff <- append(new, aff, after = j - 1L)
  }
  writeLines(with_aff, f)
  invisible(TRUE)
}

# --- Version stamp ---------------------------------------------------------

#' Record, in the easypaper: block of _quarto.yml, the version of easypaper
#' that created the project. The line of the template is replaced in place,
#' and nothing else in the file is touched; a _quarto.yml with no such line
#' gets it at the top of its easypaper: block, or a block of its own.
#' @noRd
.write_stamp <- function() {
  v <- as.character(utils::packageVersion("easypaper"))
  f <- .p("_quarto.yml")
  l <- readLines(f, warn = FALSE)
  line <- sprintf('  created: "%s"', v)
  hit <- grep("^  created:", l)
  if (length(hit)) {
    l[hit[1]] <- line
  } else {
    start <- grep("^easypaper:\\s*$", l)
    if (length(start)) {
      l <- append(l, line, after = start[1])
    } else {
      l <- c(sub("\\s+$", "", l), "", "easypaper:", line)
    }
  }
  writeLines(l, f)
  invisible(TRUE)
}

# --- git -------------------------------------------------------------------

#' Run git, quietly, and say whether it worked. `dir` is passed as -C so the
#' working directory of the session is never changed.
#' @noRd
.git <- function(args, dir = NULL) {
  if (!is.null(dir)) args <- c("-C", shQuote(dir), args)
  out <- suppressWarnings(system2("git", args, stdout = TRUE, stderr = TRUE))
  list(ok = is.null(attr(out, "status")), out = as.character(out))
}

#' git init plus the first commit, best effort.
#'
#' Never fails the creation of the project: a manuscript without a repository
#' is still a manuscript, and the commit can be made by hand later.
#' @noRd
.git_init <- function(path) {
  if (!nzchar(Sys.which("git"))) {
    message("git is not on the PATH: the project was created without a ",
            "repository.")
    return(invisible(FALSE))
  }
  if (dir.exists(file.path(path, ".git"))) return(invisible(TRUE))

  # -b main is not understood by git < 2.28; fall back to the default branch.
  if (!.git(c("init", "-b", "main", shQuote(path)))$ok) {
    .git(c("init", shQuote(path)))
  }
  if (!dir.exists(file.path(path, ".git"))) {
    message("Could not initialise the repository; the project is fine.")
    return(invisible(FALSE))
  }

  # A commit with no identity configured fails, and that is a git setting, not
  # something this package should decide for you.
  identity <- vapply(c("user.name", "user.email"), function(key) {
    r <- .git(c("config", key), dir = path)
    r$ok && length(r$out) > 0L && nzchar(r$out[1])
  }, logical(1))
  if (!all(identity)) {
    message("Repository initialised, but git has no identity configured, so ",
            "nothing was committed. Run:\n",
            "  git config --global user.name  \"Your Name\"\n",
            "  git config --global user.email \"you@example.org\"\n",
            "  git -C ", shQuote(path), " add . && git -C ", shQuote(path),
            " commit -m \"Initial manuscript structure\"")
    return(invisible(FALSE))
  }

  .git(c("add", "-A"), dir = path)
  commit <- .git(c("commit", "-m", shQuote("Initial manuscript structure")),
                 dir = path)
  if (!commit$ok) {
    message("Repository initialised, but the first commit failed:\n  ",
            paste(utils::tail(commit$out, 3), collapse = "\n  "))
    return(invisible(FALSE))
  }
  invisible(TRUE)
}
