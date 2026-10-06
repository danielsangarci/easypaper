# create_example_paper(): the project of create_paper(), with a small study
# in it. The data come from vegan; where it is not installed, a stand-in of
# the same shape takes its place.

fake_bci <- function() {
  set.seed(1)
  sp <- c("Abarema.macradenia", "Alseis.blackiana", "Faramea.occidentalis",
          "Gustavia.superba", "Inga.sp..A", "Trichilia.tuberculata",
          "Virola.sebifera")
  abund <- as.data.frame(matrix(rpois(20 * length(sp), 3), nrow = 20,
                                dimnames = list(NULL, sp)))
  env <- data.frame(UTM.EW = runif(20), UTM.NS = runif(20),
                    Habitat = factor(rep(c("OldLow", "OldSlope", "Young",
                                           "Swamp"), each = 5)),
                    River = factor(rep(c("Yes", "No"), 10)))
  list(abund = abund, env = env)
}

example_project <- function() {
  p <- tempfile("trees")
  local_mocked_bindings(.has_pkg = function(pkg) TRUE,
                        .example_bci = fake_bci,
                        .env = parent.frame())
  suppressMessages(create_example_paper(p, git = FALSE))
  p
}

test_that("it writes the project of create_paper(), with the study in it", {
  local_mocked_bindings(.has_pkg = function(pkg) TRUE,
                        .example_bci = fake_bci)
  p <- tempfile("trees")
  expect_message(out <- create_example_paper(p, git = FALSE),
                 "Example project created")
  expect_identical(out, normalizePath(p))
  # The same structure, the .Rproj named after each project, and the results
  # sections renamed after their analyses...
  blank <- tempfile("paper")
  suppressMessages(create_paper(blank, git = FALSE))
  files_of <- function(d) {
    sub("^[^/]+[.]Rproj$", "<name>.Rproj",
        list.files(d, recursive = TRUE, all.files = TRUE))
  }
  renamed <- file.path("_sections", EXAMPLE_SECTIONS)
  names(renamed) <- file.path("_sections", names(EXAMPLE_SECTIONS))
  expected <- files_of(blank)
  expected[expected %in% names(renamed)] <- renamed[expected[expected %in% names(renamed)]]
  expect_setequal(files_of(p),
                  c(expected,
                    file.path("data", c("tree_abundance.csv",
                                        "plot_environment.csv"))))
  # ...with every section written, and the example's references.
  for (f in list.files(system.file("example", "_sections", package = "easypaper"))) {
    expect_identical(readLines(file.path(p, "_sections", f)),
                     readLines(system.file("example", "_sections", f,
                                           package = "easypaper")), info = f)
  }
  bib <- readLines(file.path(p, "references", "references.bib"))
  expect_true(any(grepl("@article{Condit2002", fixed = TRUE, bib)))
  # A reference with a species in its title, written in roman, for the italics
  # of the reference list to show on; and the text cites it.
  expect_true(any(grepl("Platypodium elegans, and", bib, fixed = TRUE)))
  expect_true(any(grepl("@Augspurger1983", fixed = TRUE,
                        readLines(file.path(p, "_sections", "05_discussion.qmd")))))
})

test_that("the manuscript has its title, short title, authors and affiliations", {
  p <- example_project()
  own <- rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))
  expect_identical(own$title, EXAMPLE_TITLE)
  expect_identical(own[["short-title"]], "Habitat and tropical tree assemblages")
  expect_identical(vapply(own$author, `[[`, "", "name"), c("Charles Darwin", "Alfred Russel Wallace"))
  expect_identical(unlist(own$author[[2]]$affiliations), c("ecology", "museum"))
  expect_identical(vapply(own$affiliations, `[[`, "", "id"), c("ecology", "museum"))
  # Written for Journal of Ecology: the template's style, and no other.
  expect_identical(own$csl, "references/journal-of-ecology.csl")
  expect_identical(list_journals(path = p), "journal-of-ecology")
  expect_identical(in_project(p, .journal_name(.resolve_journal(NULL))),
                   "Journal of Ecology")
  ms <- readLines(file.path(p, "manuscript.qmd"))
  expect_false(any(grepl("Institution 1|correspondent@example.org|^# short-title", ms)))
  # The README's heading follows the title, and its authors are the example's,
  # with their affiliations, from the start.
  readme <- readLines(file.path(p, "README.md"))
  expect_identical(readme[1], paste("#", EXAMPLE_TITLE))
  # Each with the ORCID icon: a placeholder iD, there to show where it goes.
  authors <- grep("^Charles Darwin<sup>1,\\\\\\*</sup>", readme, value = TRUE)
  expect_length(authors, 1L)
  expect_match(authors, "Alfred Russel Wallace<sup>1,2</sup>", fixed = TRUE)
  expect_identical(lengths(regmatches(authors, gregexpr(
    "https://orcid.org/XXXX-XXXX-XXXX-XXXX", authors, fixed = TRUE))), 2L)
  # In the metadata of the data too; Zenodo, which would refuse it, never sees it.
  sync_metadata(quiet = TRUE, path = p)
  cr <- read.csv(file.path(p, "data", "metadata", "creators.csv"))
  expect_identical(cr$id, rep("https://orcid.org/XXXX-XXXX-XXXX-XXXX", 2))
  expect_warning(z <- in_project(p, .zenodo_metadata()), "not an ORCID iD")
  expect_null(z$creators[[1]]$orcid)
  expect_true(any(grepl("Example Natural History Museum", readme, fixed = TRUE)))
  expect_true(any(grepl("Charles Darwin & Alfred Russel Wallace", readme, fixed = TRUE)))
  # Nothing in it trips the checks every render runs first.
  expect_no_warning(check_title(quiet = TRUE, path = p))
  expect_no_error(check_crossrefs(quiet = TRUE, path = p))
  expect_no_error(suppressMessages(check_citations(path = p)))
  expect_no_warning(in_project(p, .check_authors()))
  # The five keywords, read from their one line under the abstract.
  expect_identical(in_project(p, .keywords()),
                   c("Barro Colorado Island", "beta diversity", "NMDS",
                     "PERMANOVA", "tropical trees"))
})

test_that("the data are written as a paper names them", {
  p <- example_project()
  a <- read.csv(file.path(p, "data", "tree_abundance.csv"), check.names = FALSE)
  expect_identical(names(a), c("plot", "Abarema macradenia", "Alseis blackiana",
                               "Faramea occidentalis", "Gustavia superba",
                               "Inga sp. A", "Trichilia tuberculata",
                               "Virola sebifera"))
  expect_identical(a$plot[c(1, 20)], c("P01", "P20"))
  e <- read.csv(file.path(p, "data", "plot_environment.csv"), check.names = FALSE)
  expect_identical(names(e), c("plot", "UTM.EW", "UTM.NS", "Habitat", "River"))
  expect_identical(e$plot, a$plot)
  expect_identical(sort(unique(e$Habitat)), c("OldLow", "OldSlope", "Swamp", "Young"))
  # Every file the analysis reads is there, and nothing it does not read.
  expect_no_warning(msgs <- testthat::capture_messages(check_data(path = p)))
  expect_identical(msgs, "Data: all 2 file(s) the analysis reads are in data/.\n")
})

test_that("without its packages it stops before writing anything", {
  # Not interactive: nothing is asked, nothing installed.
  asked <- FALSE
  local_mocked_bindings(.has_pkg = function(pkg) FALSE,
                        .interactive = function() FALSE,
                        .ask_yes_no = function(q) { asked <<- TRUE; TRUE })
  p <- tempfile("trees")
  expect_error(create_example_paper(p, git = FALSE),
               'install.packages("vegan")', fixed = TRUE)
  expect_false(asked)
  expect_false(dir.exists(p))
  expect_error(create_example_paper(), "`path` is missing")
})

test_that("in an interactive session it offers to install what is missing", {
  installed <- character()
  question <- NULL
  local_mocked_bindings(
    .has_pkg = function(pkg) pkg %in% installed,
    .interactive = function() TRUE,
    .ask_yes_no = function(q) { question <<- q; TRUE },
    .install_packages = function(pkgs) installed <<- c(installed, pkgs),
    .example_bci = fake_bci)
  p <- tempfile("trees")
  expect_message(create_example_paper(p, git = FALSE), "Example project created")
  expect_match(question,
               "needs vegan (its data and its analysis), which is not installed",
               fixed = TRUE)
  expect_identical(installed, "vegan")

  # A no installs nothing, and says what to run.
  installed <- character()
  local_mocked_bindings(.ask_yes_no = function(q) FALSE,
                        .install_packages = function(pkgs) stop("not asked to"))
  p <- tempfile("trees")
  expect_error(create_example_paper(p, git = FALSE),
               'install.packages("vegan")', fixed = TRUE)
  expect_false(dir.exists(p))

  # An installation that fails says so.
  local_mocked_bindings(.ask_yes_no = function(q) TRUE,
                        .install_packages = function(pkgs) invisible(NULL))
  expect_error(create_example_paper(tempfile("trees"), git = FALSE),
               'install.packages("vegan")', fixed = TRUE)
})

test_that("create_paper() still writes the structure alone", {
  p <- tempfile("paper")
  suppressMessages(create_paper(p, git = FALSE))
  expect_false(any(file.exists(file.path(p, "data", c("tree_abundance.csv",
                                                      "plot_environment.csv")))))
  expect_false(any(grepl("vegan|Condit2002",
                         unlist(lapply(list.files(file.path(p, "_sections"),
                                                  full.names = TRUE), readLines)))))
})

test_that("the analysis of the example runs on the real data", {
  skip_if_not_installed("vegan")
  skip_on_cran()
  p <- tempfile("trees")
  suppressMessages(create_example_paper(p, git = FALSE))
  local_mocked_bindings(here = function(...) file.path(p, ...), .package = "here")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  ev <- new.env(parent = globalenv())
  suppressPackageStartupMessages(source(file.path(p, "R", "setup.R"), local = ev))
  files <- file.path(p, "_sections", c("01_abstract.qmd", "02_introduction.qmd",
                                       "03_methods.qmd", "04.1_richness.qmd",
                                       "04.2_composition.qmd", "05_discussion.qmd",
                                       "10_figures.qmd", "11_tables.qmd",
                                       "12.1_suppl_material.qmd"))
  for (f in files) {
    tmp <- tempfile(fileext = ".R")
    knitr::purl(f, output = tmp, documentation = 0L, quiet = TRUE)
    code <- readLines(tmp, warn = FALSE)
    # Fewer permutations than the paper's: the test is that it runs.
    code <- sub("n_perm <- 999", "n_perm <- 99", code, fixed = TRUE)
    suppressPackageStartupMessages(suppressWarnings(
      eval(parse(text = code), envir = ev)))
    # And every number the text writes.
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    inline <- regmatches(txt, gregexpr("`r [^`]+`", txt))[[1]]
    for (x in inline) {
      v <- eval(parse(text = substr(x, 4, nchar(x) - 1)), envir = ev)
      expect_length(v, 1L)
      expect_false(is.na(v), info = x)
    }
  }
  # The supplement on its own, as render_docx() and render_pdf() render it:
  # R/setup.R and its own file, none of the objects of the Methods.
  sv <- new.env(parent = globalenv())
  suppressPackageStartupMessages(source(file.path(p, "R", "setup.R"), local = sv))
  tmp <- tempfile(fileext = ".R")
  knitr::purl(file.path(p, "_sections", "12.1_suppl_material.qmd"), output = tmp,
              documentation = 0L, quiet = TRUE)
  expect_no_error(suppressWarnings(eval(parse(file = tmp), envir = sv)))
  expect_s3_class(sv$sp_tab, "data.frame")

  expect_identical(ev$n_plots, 50L)
  expect_identical(ev$n_species, 225L)
  expect_true(all(c("Young", "OldLow", "OldSlope", "OldHigh", "Swamp") %in%
                    levels(ev$habitat)))
  expect_length(ev$top_sp, 6L)
  expect_s3_class(ev$m_rich, "glm")
  expect_s3_class(ev$nmds, "metaMDS")
  expect_true(ev$r2_hab > 0 && ev$r2_hab < 1)
  expect_false(is.na(ev$p_disp))
})

test_that("the example's results sections are named after their analyses", {
  skip_if_not_installed("vegan")
  p <- tempfile("named")
  suppressMessages(create_example_paper(p, git = FALSE))
  secs <- list.files(file.path(p, "_sections"))
  expect_true(all(c("04.1_richness.qmd", "04.2_composition.qmd") %in% secs))
  # The template's generic names are gone, and so are their include lines.
  expect_false(any(c("04.1_results1.qmd", "04.2_results2.qmd") %in% secs))
  ms <- readLines(file.path(p, "manuscript.qmd"))
  expect_true(any(grepl("_sections/04.1_richness.qmd", ms, fixed = TRUE)))
  expect_false(any(grepl("results[12]", ms)))
  # Each holds its analysis.
  expect_true(any(grepl("richness-model",
                        readLines(file.path(p, "_sections", "04.1_richness.qmd")))))
  expect_true(any(grepl("composition-model",
                        readLines(file.path(p, "_sections", "04.2_composition.qmd")))))
})
