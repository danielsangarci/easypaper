test_that("it writes the whole structure", {
  p <- file.path(tempfile("paper"))
  expect_message(create_paper(p), "Project created")

  for (f in c("_quarto.yml", "manuscript.qmd", "supplementary.qmd",
              "README.md", "R/setup.R",
              "LICENSE.txt", "LICENSE-CODE.txt", ".gitignore")) {
    expect_true(file.exists(file.path(p, f)), info = f)
  }
  for (d in c("_sections", "R", "references", "data", "data/metadata",
              "output", "figures", "cache")) {
    expect_true(dir.exists(file.path(p, d)), info = d)
  }
  # The paper and nothing else: the functions that build it live in the
  # package, and so do the Word templates. Nor a title page: make_submission()
  # builds it from the manuscript.
  for (f in c("make.R", "run.R", "format", "references_styles",
              "title_page.qmd", "R/submission.R", "R/convert_data.R")) {
    expect_false(file.exists(file.path(p, f)), info = f)
  }
  expect_identical(list.files(file.path(p, "R")), "setup.R")
  # The two files that travel renamed because R CMD build drops dotfiles and
  # the .Rproj has to take the project's name.
  expect_false(file.exists(file.path(p, "gitignore")))
  expect_false(file.exists(file.path(p, "Rproj.template")))
  expect_true(file.exists(file.path(p, paste0(basename(p), ".Rproj"))))
})

test_that("one citation style ships, the one the manuscript names", {
  # The rest are add_journal()'s job. A sync from a working project that has
  # gathered more must not carry them into the template.
  p <- tempfile("paper")
  create_paper(p)
  expect_identical(list.files(file.path(p, "references"), "[.]csl$"),
                   "journal-of-ecology.csl")
  csl <- rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))$csl
  expect_true(file.exists(file.path(p, csl)))
})

test_that("title and authors reach the YAML", {
  p <- tempfile("paper")
  create_paper(p, title = "A quoted \"title\"",
               authors = c("Ada Lovelace", "Alan Turing"))

  y <- rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))
  expect_identical(y$title, "A quoted \"title\"")
  expect_length(y$author, 2L)
  # The names alone: each points at an affiliation of its own, and the
  # numbers are worked out at render time. The first is the corresponding one.
  expect_identical(y$author[[1]]$name, "Ada Lovelace")
  expect_identical(y$author[[2]]$name, "Alan Turing")
  expect_identical(y$author[[1]]$affiliations, "aff1")
  expect_identical(y$author[[2]]$affiliations, "aff2")
  expect_true(y$author[[1]]$corresponding)
  expect_null(y$author[[2]]$corresponding)
  # Each author with a place for the ORCID iD, empty until it is written.
  expect_true("orcid" %in% names(y$author[[1]]))
  expect_null(y$author[[1]]$orcid)
  expect_true(any(grepl("orcid: .*# the ORCID iD", readLines(file.path(p, "manuscript.qmd")))))
  expect_identical(vapply(y$affiliations, function(a) a$id, character(1)),
                   c("aff1", "aff2"))
  expect_identical(.title_block(y)$line,
                   "Ada Lovelace^1,\\*^, Alan Turing^2^")
  # Written once: the README's heading follows the manuscript.
  expect_identical(readLines(file.path(p, "README.md"), n = 1L),
                   "# A quoted \"title\"")
})

test_that("the RStudio wizard's strings are accepted", {
  p <- tempfile("paper")
  # Every widget arrives as a string; an empty box arrives as "".
  create_paper(p, title = "", authors = "Ada Lovelace, Alan Turing")
  y <- rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))
  expect_identical(y$title, "Manuscript title here")   # empty: leave it alone
  expect_length(y$author, 2L)
  expect_match(y$author[[2]]$name, "^Alan Turing")
})

test_that("it refuses to write over an existing manuscript", {
  p <- tempfile("paper")
  create_paper(p)
  expect_error(create_paper(p), "already has files")
  expect_no_error(create_paper(p, overwrite = TRUE))
})

test_that("path is validated", {
  expect_error(create_paper(character(0)), "single non-empty")
  expect_error(create_paper(""), "single non-empty")
  expect_error(create_paper(c("a", "b")), "single non-empty")
})

test_that("the project records the version that created it", {
  p <- tempfile("paper")
  create_paper(p, git = FALSE)
  v <- as.character(utils::packageVersion("easypaper"))
  y <- yaml::read_yaml(file.path(p, "_quarto.yml"))$easypaper
  expect_identical(y$created, v)
  # Written in place: the block keeps its comments and its other settings.
  l <- readLines(file.path(p, "_quarto.yml"))
  expect_identical(sum(grepl("^  created:", l)), 1L)
  expect_true(isTRUE(y[["italicize-species"]]))

  # A _quarto.yml with no line, or no block, gets one.
  f <- file.path(p, "_quarto.yml")
  writeLines(l[!grepl("^  created:", l)], f)
  in_project(p, .write_stamp())
  expect_identical(yaml::read_yaml(f)$easypaper$created, v)
  writeLines(l[seq_len(grep("^# --- easypaper", l) - 1L)], f)
  in_project(p, .write_stamp())
  expect_identical(yaml::read_yaml(f)$easypaper$created, v)
})

test_that("the title becomes the heading of the project's README", {
  p <- tempfile("paper")
  create_paper(p, title = "Chemical mimicry in ants", git = FALSE)
  expect_identical(readLines(file.path(p, "README.md"), n = 1L),
                   "# Chemical mimicry in ants")
})

test_that("it says what to do next, and it is library(easypaper)", {
  p <- tempfile("paper")
  said <- capture_messages(create_paper(p, git = FALSE))
  expect_true(any(grepl("library(easypaper)", said, fixed = TRUE)))
  expect_false(any(grepl("make.R", said, fixed = TRUE)))
})

test_that("git = TRUE leaves a repository with one commit", {
  skip_if(!nzchar(Sys.which("git")), "git is not installed")
  p <- tempfile("paper")
  create_paper(p, git = TRUE)
  expect_true(dir.exists(file.path(p, ".git")))

  who <- suppressWarnings(system2("git", c("-C", shQuote(p), "config",
                                           "user.email"),
                                  stdout = TRUE, stderr = FALSE))
  skip_if(!length(who) || !nzchar(who[1]), "git has no identity configured")

  log <- suppressWarnings(system2("git", c("-C", shQuote(p), "log",
                                           "--oneline"),
                                  stdout = TRUE, stderr = TRUE))
  expect_length(log, 1L)
  expect_match(log, "Initial manuscript structure")

  # Nothing left uncommitted, and nothing regenerable committed by mistake.
  status <- suppressWarnings(system2("git", c("-C", shQuote(p), "status",
                                              "--porcelain"),
                                     stdout = TRUE, stderr = TRUE))
  expect_length(status, 0L)
  tracked <- suppressWarnings(system2("git", c("-C", shQuote(p), "ls-files"),
                                      stdout = TRUE, stderr = TRUE))
  expect_true(any(grepl("^manuscript[.]qmd$", tracked)))
  expect_false(any(grepl("^(output|figures|cache|submission)/", tracked)))
})

test_that("git = FALSE leaves no repository", {
  p <- tempfile("paper")
  create_paper(p, git = FALSE)
  expect_false(dir.exists(file.path(p, ".git")))
})

test_that("a title with quotes and backslashes reaches the YAML intact", {
  p <- tempfile("paper")
  title <- 'Effects of \\textit{Formica} on "guests" and C:\\path'
  create_paper(p, title = title, git = FALSE)
  expect_identical(
    rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))$title, title)
})

test_that("a title given as a vector is one title, not a broken header", {
  p <- tempfile("paper")
  expect_no_warning(
    create_paper(p, title = c("Chemical mimicry", "in ants"), git = FALSE))
  expect_identical(
    rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))$title,
    "Chemical mimicry in ants")
})

test_that("author names are escaped like the title", {
  p <- tempfile("paper")
  create_paper(p, authors = c('Conan "the" O\'Brien', "Zoe Mueller"),
               git = FALSE)
  y <- rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))
  expect_identical(y$author[[1]]$name, 'Conan "the" O\'Brien')
  expect_identical(y$author[[2]]$name, "Zoe Mueller")
})

test_that("every argument is checked before anything is written", {
  p <- tempfile("paper")
  expect_error(create_paper(), "missing")
  expect_error(create_paper(NA_character_), "single non-empty")
  expect_error(create_paper(p, title = 42), "`title`")
  expect_error(create_paper(p, authors = list("a")), "`authors`")
  expect_error(create_paper(p, overwrite = NA), "`overwrite`")
  expect_error(create_paper(p, git = "yes"), "`git`")
  expect_error(create_paper(p, open = c(TRUE, FALSE)), "`open`")
  expect_false(dir.exists(p))
})

test_that("a path that exists as a file is refused", {
  f <- tempfile("paper")
  writeLines("x", f)
  expect_error(create_paper(f), "is a file")
})

test_that("the project takes its name from the resolved path", {
  # "." and a trailing slash both used to give the .Rproj a wrong name.
  p <- tempfile("paper")
  dir.create(p)
  old <- setwd(p); on.exit(setwd(old), add = TRUE)
  out <- create_paper(".", git = FALSE)
  expect_identical(basename(out), basename(p))
  expect_true(file.exists(file.path(p, paste0(basename(p), ".Rproj"))))

  q <- tempfile("paper")
  create_paper(paste0(q, "/"), git = FALSE)
  expect_true(file.exists(file.path(q, paste0(basename(q), ".Rproj"))))
})

test_that("the YAML is edited only inside its fences", {
  # `title:` and `author:` used to be looked for anywhere in the file, and the
  # author block was assumed to be followed by another key: a list at the end
  # of the header would have swallowed the closing fence and the body.
  f <- tempfile(fileext = ".qmd")
  writeLines(c("---",
               "title: \"Old\"",
               "author:",
               "  - name: \"A^1^\"",
               "  - name: \"B^2^\"",
               "---",
               "",
               "title: this is prose, not metadata",
               "author: so is this"), f)
  expect_true(.set_title(f, "New"))
  expect_true(.set_authors(f, c("Ada", "Alan")))
  y <- rmarkdown::yaml_front_matter(f)
  expect_identical(y$title, "New")
  expect_length(y$author, 2L)
  expect_identical(y$author[[2]]$name, "Alan")
  # A header with no list of affiliations is given one, under the authors.
  expect_identical(length(y$affiliations), 2L)
  expect_identical(.title_block(y)$line, "Ada^1,\\*^, Alan^2^")
  l <- readLines(f)
  expect_identical(sum(l == "---"), 2L)
  expect_identical(utils::tail(l, 2),
                   c("title: this is prose, not metadata",
                     "author: so is this"))
})

test_that("a file with no front matter is left alone", {
  f <- tempfile(fileext = ".qmd")
  writeLines(c("# Heading", "title: x"), f)
  expect_false(.set_title(f, "New"))
  expect_identical(readLines(f), c("# Heading", "title: x"))
})

test_that("open = TRUE outside RStudio says so instead of doing nothing", {
  skip_if(requireNamespace("rstudioapi", quietly = TRUE) &&
            rstudioapi::isAvailable(), "running inside RStudio")
  p <- tempfile("paper")
  expect_message(create_paper(p, git = FALSE, open = TRUE), "rstudioapi")
})

test_that("output/ is one flat folder, with no subfolders", {
  # A render writes straight into output/. The three subfolders it used to
  # sort results into were created here, so this is where they would come back.
  p <- tempfile("paper")
  create_paper(p, git = FALSE)
  expect_true(dir.exists(file.path(p, "output")))
  expect_identical(list.dirs(file.path(p, "output"), recursive = TRUE),
                   file.path(p, "output"))
})

test_that("the RStudio wizard opens a file the project has", {
  # It opened make.R, which projects no longer carry.
  dcf <- read.dcf(system.file("rstudio", "templates", "project",
                              "create_paper.dcf", package = "easypaper"))
  opened <- trimws(strsplit(dcf[1, "OpenFiles"], ",")[[1]])
  p <- new_project()
  for (f in opened) expect_true(file.exists(file.path(p, f)), info = f)
})
