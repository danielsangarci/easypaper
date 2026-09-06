test_that("it writes the whole structure", {
  p <- file.path(tempfile("paper"))
  expect_message(create_paper(p), "Project created")

  for (f in c("_quarto.yml", "manuscript.qmd", "supplementary.qmd",
              "title_page.qmd", "make.R", "run.R", "README.md",
              "LICENSE", "LICENSE-CODE", ".gitignore")) {
    expect_true(file.exists(file.path(p, f)), info = f)
  }
  for (d in c("_sections", "R", "format", "references", "references_styles",
              "data/raw", "data/processed", "data/metadata",
              "output/journal", "output/preprint", "output/supplementary",
              "figures", "cache")) {
    expect_true(dir.exists(file.path(p, d)), info = d)
  }
  # The two files that travel renamed because R CMD build drops dotfiles and
  # the .Rproj has to take the project's name.
  expect_false(file.exists(file.path(p, "gitignore")))
  expect_false(file.exists(file.path(p, "Rproj.template")))
  expect_true(file.exists(file.path(p, paste0(basename(p), ".Rproj"))))
})

test_that("title and authors reach the YAML", {
  p <- tempfile("paper")
  create_paper(p, title = "A quoted \"title\"",
               authors = c("Ada Lovelace", "Alan Turing"))

  y <- rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))
  expect_identical(y$title, "A quoted \"title\"")
  expect_length(y$author, 2L)
  # The affiliation mark is embedded in the name: Quarto rebuilds the author
  # line of a .docx and drops any structured affiliation.
  expect_match(y$author[[1]]$name, "^Ada Lovelace\\^1,\\\\\\*\\^$")
  expect_match(y$author[[2]]$name, "^Alan Turing\\^2\\^$")
  # The title page must not disagree with the manuscript.
  expect_identical(rmarkdown::yaml_front_matter(
    file.path(p, "title_page.qmd"))$title, y$title)
})

test_that("the RStudio wizard's strings are accepted", {
  p <- tempfile("paper")
  # Every widget arrives as a string; an empty box arrives as "".
  create_paper(p, title = "", authors = "Ada Lovelace, Alan Turing")
  y <- rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))
  expect_identical(y$title, "TITLE HERE")      # empty means "leave it alone"
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
