test_that("it writes the whole structure", {
  p <- file.path(tempfile("paper"))
  expect_message(create_paper(p), "Project created")

  for (f in c("_quarto.yml", "manuscript.qmd", "supplementary.qmd",
              "title_page.qmd", "make.R", "run.R", "README.md",
              "LICENSE", "LICENSE-CODE", ".gitignore")) {
    expect_true(file.exists(file.path(p, f)), info = f)
  }
  for (d in c("_sections", "R", "format", "references", "references_styles",
              "data", "data/metadata",
              "output",
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

test_that("the project records the version that created it", {
  p <- tempfile("paper")
  create_paper(p, git = FALSE)
  # The stamp goes at the very top, before the banner, so it survives any
  # future change to the template's make.R.
  top <- readLines(file.path(p, "make.R"), warn = FALSE, n = 2L)
  expect_match(top[1], "easypaper")
  expect_match(top[1], as.character(utils::packageVersion("easypaper")),
               fixed = TRUE)
  # And it is a comment: make.R still has to be sourceable.
  expect_match(top[1], "^#")
  expect_no_error(parse(file.path(p, "make.R")))
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
  expect_identical(
    rmarkdown::yaml_front_matter(file.path(p, "title_page.qmd"))$title, title)
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
  expect_identical(y$author[[1]]$name, 'Conan "the" O\'Brien^1,\\*^')
  expect_identical(y$author[[2]]$name, "Zoe Mueller^2^")
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
  expect_match(y$author[[2]]$name, "^Alan\\^2\\^$")
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
