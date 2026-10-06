# ---------------------------------------------------------------------------
# create_example_paper() -- the project create_paper() writes, with a small
# study in it: the BCI data of vegan, analysed, written up and cited,
# so every part of a manuscript can be seen written the way the package
# expects it.
# ---------------------------------------------------------------------------

#' Create an example project: a small study, written as an easypaper paper
#'
#' Writes the same project as [create_paper()], with a short study in it
#' instead of empty sections: the trees of Barro Colorado Island, Panama, as
#' the vegan package distributes them (`BCI`), analysed, written up and cited.
#' Every part of a
#' manuscript is there, written the way the package expects it, to read,
#' render and copy from:
#'
#' ```
#' manuscript.qmd              title, short title, authors with shared
#'                             affiliations and their ORCID iDs, the
#'                             corresponding author
#' _sections/01_abstract.qmd   the abstract, and the keywords under it
#' _sections/02_introduction   citations in brackets and in the sentence
#' _sections/03_methods        the text of the Methods, and a chunk that reads
#'                             the data from data/ for every analysis
#' _sections/04.1_richness     each analysis beside its text, in a file named
#' _sections/04.2_composition  after it: a GLM of richness; a PERMANOVA, a
#'                             PERMDISP and an NMDS of composition;
#'                             numbers written by inline R, never typed;
#'                             scientific names written by R, in italics
#' _sections/10_figures        two figures: an NMDS with names in italics
#' _sections/11_tables         two flextables, with the three rules
#' _sections/12.1_suppl        a supplementary figure and table
#' _sections/06-09             the statements at the end, filled in
#' data/                       the two tables of BCI, as .csv
#' references/                 the five references the text cites, one
#'                             with a species in its title, set in italics
#'                             by every render; the style is the
#'                             template's, Journal of Ecology
#' ```
#'
#' [create_paper()] stays the one to start a paper of your own with: it
#' writes the structure and nothing else.
#'
#' It needs one package, vegan: its `BCI` and `BCI.env` data are written into
#' `data/`, and the analysis uses it. When it is missing, it is offered for
#' installation -- in an interactive session; elsewhere the function stops
#' and says what to install. The data were collected by Condit et al.
#' (2002), *Science* 295: 666--669, \doi{10.1126/science.1066854}: cite them,
#' not this example, if you use them. The authors of the example are
#' borrowed from the history of the field -- Charles Darwin and Alfred
#' Russel Wallace, who never wrote it -- and their affiliations, emails and
#' ORCID iDs are made up.
#'
#' @inheritParams create_paper
#' @return The absolute path of the created project, invisibly.
#' @seealso [create_paper()], for a project of your own.
#' @export
#' @examples
#' if (requireNamespace("vegan", quietly = TRUE)) {
#'   dir <- file.path(tempdir(), "example_paper")
#'   create_example_paper(dir, git = FALSE)
#'   list.files(file.path(dir, "data"))
#'   unlink(dir, recursive = TRUE)
#' }
#'
#' \dontrun{
#' create_example_paper("example_paper", open = TRUE)
#' # then, in the project:
#' render_html()
#' }
create_example_paper <- function(path, overwrite = FALSE, git = TRUE,
                                 open = FALSE) {
  if (missing(path)) {
    stop("`path` is missing: give the directory to create.", call. = FALSE)
  }
  .check_flag(git, "git")
  .check_flag(open, "open")
  # Before anything is written: without vegan there are no data, and the
  # analysis does not run.
  .example_packages()

  path <- suppressMessages(create_paper(path, title = EXAMPLE_TITLE,
                                        authors = c("Charles Darwin", "Alfred Russel Wallace"),
                                        overwrite = overwrite, git = FALSE,
                                        open = FALSE))
  .copy_example(path)
  .rename_sections(path, EXAMPLE_SECTIONS)
  .example_front_matter(file.path(path, "manuscript.qmd"))
  .sync_new_project(path)
  .write_example_data(file.path(path, "data"), .example_bci())

  if (git) .git_init(path)

  message("Example project created: ", path, "\n",
          "  1. open ", basename(path), ".Rproj\n",
          "  2. library(easypaper)\n",
          "  3. render_html()      # the study, rendered\n",
          "  The sections are in _sections/: read them to see how each part ",
          "is written.")

  if (open) {
    if (requireNamespace("rstudioapi", quietly = TRUE) &&
        rstudioapi::isAvailable()) {
      rstudioapi::openProject(path, newSession = TRUE)
    } else {
      message("open = TRUE needs an RStudio session and the rstudioapi ",
              "package: open ", basename(path), ".Rproj by hand.")
    }
  }
  invisible(path)
}

EXAMPLE_TITLE <- paste("Habitat and the tree assemblages of a tropical",
                       "forest: a worked example with the BCI data")

#' The results sections of the example, named the way an author renames the
#' template's: after the analysis each one holds.
#' @noRd
EXAMPLE_SECTIONS <- c("04.1_results1.qmd" = "04.1_richness.qmd",
                      "04.2_results2.qmd" = "04.2_composition.qmd")

#' Rename sections of a project: the template's file goes, and its include
#' line in manuscript.qmd names the new one. The new file is already there,
#' copied with the example.
#' @noRd
.rename_sections <- function(path, renames) {
  ms <- file.path(path, "manuscript.qmd")
  l <- readLines(ms, warn = FALSE)
  for (old in names(renames)) {
    unlink(file.path(path, "_sections", old))
    l <- gsub(paste0("_sections/", old), paste0("_sections/", renames[[old]]),
              l, fixed = TRUE)
  }
  writeLines(l, ms)
  invisible(path)
}

#' The packages the example needs, and what for.
#' @noRd
EXAMPLE_PACKAGES <- c(vegan = "its data and its analysis")

#' Is a package installed? A function of its own, so the tests can say no.
#' @noRd
.has_pkg <- function(pkg) requireNamespace(pkg, quietly = TRUE)

#' Check that the example's packages are installed, and offer to install the
#' missing ones: asked in an interactive session, never installed without a
#' yes. Elsewhere -- a script, a check -- it stops and says what to run.
#' @noRd
.example_packages <- function() {
  have <- vapply(names(EXAMPLE_PACKAGES), .has_pkg, logical(1))
  missing <- names(EXAMPLE_PACKAGES)[!have]
  if (!length(missing)) return(invisible(TRUE))
  what <- paste0(missing, " (", EXAMPLE_PACKAGES[missing], ")")
  question <- paste0("The example needs ", knitr::combine_words(what), ", ",
                     if (length(missing) == 1L) "which is" else "which are",
                     " not installed. Install now?")
  if (.interactive() && isTRUE(.ask_yes_no(question))) {
    .install_packages(missing)
    still <- missing[!vapply(missing, .has_pkg, logical(1))]
    if (!length(still)) return(invisible(TRUE))
    missing <- still
  }
  cmd <- if (length(missing) == 1L) sprintf('install.packages("%s")', missing)
         else sprintf("install.packages(c(%s))",
                      paste0('"', missing, '"', collapse = ", "))
  stop("create_example_paper() needs ", knitr::combine_words(missing),
       ", not installed. Install ", if (length(missing) == 1L) "it" else "them",
       " first: ", cmd, call. = FALSE)
}

#' The three things the offer to install depends on, each a function of its
#' own so the tests can answer for the user.
#' @noRd
.interactive <- function() interactive()
#' @noRd
.ask_yes_no <- function(question) utils::askYesNo(question)
#' @noRd
.install_packages <- function(pkgs) utils::install.packages(pkgs)

#' The BCI data of vegan: `abund`, the trees of each species in each plot,
#' and `env`, the habitat and the place of each plot.
#' @noRd
.example_bci <- function() {
  e <- new.env()
  utils::data("BCI", "BCI.env", package = "vegan", envir = e)
  list(abund = e$BCI, env = e$BCI.env)
}

#' The example's sections and references, over the template's.
#' @noRd
.copy_example <- function(path) {
  src <- system.file("example", package = "easypaper")
  if (!nzchar(src) || !dir.exists(src)) {
    stop("The example is missing from the installed package.", call. = FALSE)
  }
  files <- list.files(src, recursive = TRUE, all.files = TRUE)
  ok <- vapply(files, function(f) {
    to <- file.path(path, f)
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(src, f), to, overwrite = TRUE)
  }, logical(1))
  if (!all(ok)) {
    stop("Could not copy the example into `", path, "`.", call. = FALSE)
  }
  invisible(path)
}

#' The authors with their affiliations -- one of them shared, one author with
#' two -- and their ORCID iDs, and a short title, in the YAML of
#' manuscript.qmd. The ORCID iDs are placeholders: they show where each goes
#' in the README and the metadata, and deposit_zenodo() leaves them out.
#' @noRd
.example_front_matter <- function(f) {
  l <- readLines(f, warn = FALSE)
  l <- .replace_yaml_key(l, "author", c(
    "author:",
    '  - name: "Charles Darwin"',
    "    affiliations: [ecology]",
    "    orcid: XXXX-XXXX-XXXX-XXXX",
    "    email: charles.darwin@example.org",
    "    corresponding: true",
    '  - name: "Alfred Russel Wallace"',
    "    affiliations: [ecology, museum]",
    "    orcid: XXXX-XXXX-XXXX-XXXX"))
  l <- .replace_yaml_key(l, "affiliations", c(
    "affiliations:",
    "  - id: ecology",
    "    address: Example University, Department of Ecology, Example City, Country",
    "  - id: museum",
    "    address: Example Natural History Museum, Example City, Country"))
  l <- sub('^# short-title: .*$', 'short-title: "Habitat and tropical tree assemblages"', l)
  writeLines(l, f)
  invisible(f)
}

#' The two tables of BCI, as .csv in data/: the trees of each species in
#' each plot, and the habitat and the place of each plot. Species are named as
#' a paper names them, "Abarema macradenia", not as R names columns.
#' @noRd
.write_example_data <- function(dir, bci) {
  abund <- as.data.frame(bci$abund)
  env <- as.data.frame(bci$env)
  plot <- sprintf("P%02d", seq_len(nrow(abund)))
  a <- data.frame(plot = plot, abund, check.names = FALSE)
  names(a) <- c("plot", .species_from_column(colnames(abund)))
  e <- data.frame(plot = plot, env, check.names = FALSE)
  utils::write.csv(a, file.path(dir, "tree_abundance.csv"), row.names = FALSE)
  utils::write.csv(e, file.path(dir, "plot_environment.csv"), row.names = FALSE)
  invisible(dir)
}

#' "Abarema.macradenia" -> "Abarema macradenia";
#' "Inga.sp..A" -> "Inga sp. A".
#' @noRd
.species_from_column <- function(x) {
  x <- gsub("..", ". ", x, fixed = TRUE)
  gsub("\\.(?=\\S)", " ", x, perl = TRUE)
}
