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
#' @param path Directory to create. Its base name becomes the name of the
#'   `.Rproj` file.
#' @param title Manuscript title, written into the YAML of `manuscript.qmd`.
#'   `NULL` leaves the placeholder, which `make.R` warns about.
#' @param authors Character vector of author names, in order. The first one is
#'   marked as the corresponding author. Affiliations are not guessed: fill
#'   them in `_sections/0_authors.qmd`. `NULL` leaves the placeholders.
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
#' @param open Open the new project in RStudio when the session allows it.
#'
#' @return The path of the created project, invisibly.
#'
#' @examples
#' \dontrun{
#' create_paper("~/papers/ant_chemistry",
#'              title   = "Chemical mimicry in Maculinea rebeli",
#'              authors = c("Daniel Sanchez-Garcia", "Second Author"))
#' }
#' @export
create_paper <- function(path, title = NULL, authors = NULL,
                         overwrite = FALSE, git = TRUE, open = FALSE) {
  if (missing(path) || !is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop("`path` must be a single non-empty directory path.", call. = FALSE)
  }
  path <- path.expand(path)

  # The RStudio project wizard passes every widget as a string, and an empty
  # box as "". Authors arrive as one comma-separated line.
  if (!is.null(title) && !nzchar(trimws(paste(title, collapse = "")))) title <- NULL
  if (!is.null(authors)) {
    authors <- trimws(unlist(strsplit(paste(authors, collapse = ","), ",")))
    authors <- authors[nzchar(authors)]
    if (!length(authors)) authors <- NULL
  }

  if (dir.exists(path) && length(list.files(path, all.files = TRUE,
                                            no.. = TRUE)) && !overwrite) {
    stop("`", path, "` already has files in it. Use overwrite = TRUE if you ",
         "really mean to write into it.", call. = FALSE)
  }
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  tpl <- system.file("template", package = "easypaper")
  if (!nzchar(tpl) || !dir.exists(tpl)) {
    stop("The template is missing from the installed package.", call. = FALSE)
  }

  ok <- file.copy(list.files(tpl, full.names = TRUE, all.files = TRUE,
                             no.. = TRUE),
                  path, recursive = TRUE, copy.date = TRUE)
  if (!all(ok)) stop("Could not copy the template into `", path, "`.", call. = FALSE)

  # .gitignore travels as `gitignore`: R CMD build drops dotfiles from inst/.
  file.rename(file.path(path, "gitignore"), file.path(path, ".gitignore"))
  # The .Rproj is named after the project so RStudio's recent list is readable.
  file.rename(file.path(path, "Rproj.template"),
              file.path(path, paste0(basename(path), ".Rproj")))

  # Folders git cannot carry empty, and the ones make.R writes into.
  for (d in c("data/raw", "data/processed", "data/metadata")) {
    dir.create(file.path(path, d), recursive = TRUE, showWarnings = FALSE)
    file.create(file.path(path, d, ".gitkeep"))
  }
  for (d in c("output/journal", "output/preprint", "output/supplementary",
              "figures", "cache")) {
    dir.create(file.path(path, d), recursive = TRUE, showWarnings = FALSE)
  }

  if (!is.null(title)) {
    # Both files: make.R rewrites the title page from the manuscript when it
    # builds a submission, but a standalone render reads title_page.qmd itself.
    .set_title(file.path(path, "manuscript.qmd"), title)
    .set_title(file.path(path, "title_page.qmd"), title)
  }
  if (!is.null(authors)) .set_authors(file.path(path, "manuscript.qmd"), authors)

  .stamp_version(file.path(path, "make.R"))

  if (isTRUE(git)) .git_init(path)

  message("Project created: ", path, "\n",
          "  1. open ", basename(path), ".Rproj\n",
          "  2. source(\"make.R\")\n",
          "  3. render_html()      # or see run.R for every command")

  if (open && requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    rstudioapi::openProject(path, newSession = TRUE)
  }
  invisible(path)
}

#' Replace the `title:` line of a .qmd YAML header.
#' @noRd
.set_title <- function(f, title) {
  l <- readLines(f, warn = FALSE)
  i <- grep("^title:", l)
  if (!length(i)) return(invisible(FALSE))
  l[i[1]] <- sprintf('title: "%s"', gsub('"', '\\\\"', title))
  writeLines(l, f)
  invisible(TRUE)
}

#' Rewrite the `author:` block, keeping the affiliation-mark convention:
#' the marks are embedded in the name because Quarto rebuilds the author line
#' of a .docx and drops any structured affiliation.
#' @noRd
.set_authors <- function(f, authors) {
  l <- readLines(f, warn = FALSE)
  i <- grep("^author:", l)
  if (!length(i)) return(invisible(FALSE))
  i <- i[1]
  # The block runs until the next line that starts a new top-level key.
  j <- i + 1L
  while (j <= length(l) && !grepl("^[A-Za-z_-]+:", l[j])) j <- j + 1L
  marks <- sprintf("^%d%s^", seq_along(authors),
                   ifelse(seq_along(authors) == 1L, ",\\\\*", ""))
  block <- c("author:", sprintf('  - name: "%s%s"', authors, marks))
  writeLines(c(l[seq_len(i - 1L)], block, l[seq.int(j, length(l))]), f)
  invisible(TRUE)
}

#' Record, at the top of the project's make.R, the version that wrote it.
#'
#' The project carries its own build logic and never needs easypaper again;
#' the stamp answers the other question, the one that only comes up years
#' later: which version of the scaffold produced this structure. Best effort,
#' like the repository: a project without the line is still a whole project.
#' @noRd
.stamp_version <- function(f) {
  if (!file.exists(f)) return(invisible(FALSE))
  v <- tryCatch(as.character(utils::packageVersion("easypaper")),
                error = function(e) NA_character_)
  if (is.na(v)) return(invisible(FALSE))
  writeLines(c(
    sprintf("# Structure created by easypaper %s on %s. This project carries",
            v, format(Sys.Date())),
    "# its own build logic: it renders without easypaper installed.",
    "",
    readLines(f, warn = FALSE)), f)
  invisible(TRUE)
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

  # -b main is not understood by git < 2.28; fall back and rename after.
  out <- suppressWarnings(system2("git", c("init", "-b", "main", shQuote(path)),
                                  stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(out, "status"))) {
    suppressWarnings(system2("git", c("init", shQuote(path)),
                             stdout = TRUE, stderr = TRUE))
  }
  if (!dir.exists(file.path(path, ".git"))) {
    message("Could not initialise the repository; the project is fine.")
    return(invisible(FALSE))
  }

  # A commit with no identity configured fails, and that is a git setting, not
  # something this package should decide for you.
  who <- suppressWarnings(system2("git", c("-C", shQuote(path), "config",
                                           "user.email"),
                                  stdout = TRUE, stderr = FALSE))
  if (!length(who) || !nzchar(who[1])) {
    message("Repository initialised, but git has no identity configured, so ",
            "nothing was committed. Run:\n",
            "  git config --global user.name  \"Your Name\"\n",
            "  git config --global user.email \"you@example.org\"\n",
            "  git -C ", path, " add . && git -C ", path,
            " commit -m \"Initial manuscript structure\"")
    return(invisible(FALSE))
  }

  suppressWarnings(system2("git", c("-C", shQuote(path), "add", "-A"),
                           stdout = TRUE, stderr = TRUE))
  out <- suppressWarnings(system2("git", c("-C", shQuote(path), "commit", "-m",
                                           shQuote("Initial manuscript structure")),
                                  stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(out, "status"))) {
    message("Repository initialised, but the first commit failed:\n  ",
            paste(utils::tail(out, 3), collapse = "\n  "))
    return(invisible(FALSE))
  }
  invisible(TRUE)
}
