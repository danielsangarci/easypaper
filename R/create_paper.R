#' Create a reproducible Quarto manuscript project
#'
#' Writes, into `path`, the complete structure of a reproducible manuscript:
#' the sections as separate `.qmd` files, `make.R` as the single entry point,
#' the journal styles, the Word templates and the folders for data, figures
#' and outputs.
#'
#' The build logic is **copied into the project**, not kept in this package.
#' That is deliberate: the submission compendium ships `scripts/`, and a
#' reviewer reproducing your analysis should not have to install easypaper to
#' do it. Once created, the project is self-contained and this package is no
#' longer needed.
#'
#' The top of the project's `make.R` records the version of easypaper that
#' wrote the structure. The project never needs the package again, but if the
#' scaffold changes in the future, the stamp is what tells you which version
#' produced a project you already have.
#'
#' Every argument is checked before anything is written, so a wrong call
#' stops with a message naming the argument and leaves no half-made project
#' behind.
#'
#' @param path Directory to create, as a single non-empty string; `~` is
#'   expanded. Its base name becomes the name of the `.Rproj` file. A path
#'   that exists as a file is refused.
#' @param title Manuscript title, written into the YAML of `manuscript.qmd`
#'   and `title_page.qmd`. Quotes and backslashes are escaped for YAML, so a
#'   LaTeX fragment such as `\textit{Formica}` survives. A vector is joined
#'   with spaces. `NULL` or `""` leaves the placeholder, which `make.R` warns
#'   about.
#' @param authors Character vector of author names, in order, or one
#'   comma-separated string, which is how the RStudio wizard sends them. The
#'   first one is marked as the corresponding author. Affiliations are not
#'   guessed: fill them in `_sections/0_authors.qmd`. `NULL` or an empty
#'   string leaves the placeholders.
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
#' @seealso [convert_data()] to bring the data into the project's `data/`
#'   folder, and `vignette("easypaper")` for a tour of what the project can do.
#'
#' @examples
#' dir <- file.path(tempdir(), "paper_name")
#' create_paper(dir,
#'              title   = "Manuscript title here",
#'              authors = c("First Author", "Second Author"),
#'              git     = FALSE)
#' list.files(dir)
#' unlink(dir, recursive = TRUE)
#'
#' \dontrun{
#' # A real project, with its git history started for you:
#' create_paper("~/paper_name",
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
    # Both files: make.R rewrites the title page from the manuscript when it
    # builds a submission, but a standalone render reads title_page.qmd itself.
    .set_title(file.path(path, "manuscript.qmd"), title)
    .set_title(file.path(path, "title_page.qmd"), title)
  }
  if (!is.null(authors)) {
    .set_authors(file.path(path, "manuscript.qmd"), authors)
  }

  .stamp_version(file.path(path, "make.R"))

  if (git) .git_init(path)

  message("Project created: ", path, "\n",
          "  1. open ", name, ".Rproj\n",
          "  2. source(\"make.R\")\n",
          "  3. render_html()      # or see run.R for every command")

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

#' The folders git cannot carry empty, and the ones make.R writes into.
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

#' Replace the `title:` of a .qmd front matter.
#' @noRd
.set_title <- function(f, title) {
  l <- readLines(f, warn = FALSE)
  new <- .replace_yaml_key(l, "title", paste0("title: ", .yaml_quote(title)))
  if (is.null(new)) return(invisible(FALSE))
  writeLines(new, f)
  invisible(TRUE)
}

#' Rewrite the `author:` block, keeping the affiliation-mark convention:
#' the marks are embedded in the name because Quarto rebuilds the author line
#' of a .docx and drops any structured affiliation. The first author carries
#' the correspondence asterisk.
#' @noRd
.set_authors <- function(f, authors) {
  l <- readLines(f, warn = FALSE)
  n <- length(authors)
  marks <- paste0("^", seq_len(n), c(",\\*", rep("", n - 1L)), "^")
  block <- c("author:",
             paste0("  - name: ", .yaml_quote(paste0(authors, marks))))
  new <- .replace_yaml_key(l, "author", block)
  if (is.null(new)) return(invisible(FALSE))
  writeLines(new, f)
  invisible(TRUE)
}

# --- Version stamp ---------------------------------------------------------

#' Record, at the top of the project's make.R, the version that wrote it.
#'
#' The project carries its own build logic and never needs easypaper again;
#' the stamp answers the other question, the one that only comes up years
#' later: which version of the scaffold produced this structure. Best effort,
#' like the repository: a project without the line is still a whole project.
#'
#' Idempotent: an existing stamp is replaced, not buried. When the project was
#' created by an earlier version, the new line keeps that version and adds the
#' one it was updated to, which is what update_project() relies on. `created`
#' is that earlier version, for when the file is a fresh copy of the template
#' and no longer carries the old stamp itself.
#' @noRd
.stamp_version <- function(f, created = NULL) {
  if (!file.exists(f)) return(invisible(FALSE))
  v <- tryCatch(as.character(utils::packageVersion("easypaper")),
                error = function(e) NA_character_)
  if (is.na(v)) return(invisible(FALSE))
  if (is.null(created)) {
    old <- .stamp_info(f)
    if (!is.null(old)) created <- old$created
  }
  origin <- if (is.null(created)) v else as.character(created)
  head <- if (identical(origin, v)) {
    sprintf("# Structure created by easypaper %s on %s. This project carries",
            v, format(Sys.Date()))
  } else {
    sprintf("# Structure created by easypaper %s, updated to %s on %s. This project carries",
            origin, v, format(Sys.Date()))
  }
  writeLines(c(
    head,
    "# its own build logic: it renders without easypaper installed.",
    "",
    .strip_stamp(readLines(f, warn = FALSE))), f)
  invisible(TRUE)
}

#' The versions a make.R stamp records: `created`, and `current` -- the same
#' one unless the project has been updated. NULL when there is no stamp.
#' @noRd
.stamp_info <- function(f) {
  if (!file.exists(f)) return(NULL)
  l <- readLines(f, n = 1L, warn = FALSE)
  if (!length(l) || !grepl("^# Structure created by easypaper ", l)) return(NULL)
  v <- regmatches(l, gregexpr("(?<=easypaper |updated to )[0-9]+(?:[.-][0-9]+)+",
                              l, perl = TRUE))[[1]]
  v <- tryCatch(package_version(v), error = function(e) NULL)
  if (!length(v)) return(NULL)
  list(created = v[1], current = v[length(v)])
}

#' The stamp is two comment lines and the blank line after them. Strip it, so
#' a file can be compared with the template or stamped again.
#' @noRd
.strip_stamp <- function(l) {
  if (!length(l) || !grepl("^# Structure created by easypaper ", l[1])) return(l)
  n <- 1L
  if (length(l) >= 2L && grepl("^# its own build logic", l[2])) n <- 2L
  if (length(l) > n && !nzchar(trimws(l[n + 1L]))) n <- n + 1L
  l[-seq_len(n)]
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
