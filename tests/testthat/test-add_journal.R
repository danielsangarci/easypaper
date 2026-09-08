# A local stand-in for the CSL repository: one independent style, one
# dependent style pointing at it, and one file that is not a style at all.
fake_repo <- function() {
  r <- tempfile("csl")
  dir.create(file.path(r, "dependent"), recursive = TRUE)
  writeLines(c(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">',
    '  <info>',
    '    <title>American Psychological Association 7th edition</title>',
    '    <id>http://www.zotero.org/styles/apa</id>',
    '  </info>',
    '  <citation><layout><text variable="title"/></layout></citation>',
    '  <bibliography><layout><text variable="title"/></layout></bibliography>',
    '</style>'), file.path(r, "apa.csl"))
  writeLines(c(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<style xmlns="http://purl.org/net/xbiblio/csl" version="1.0" default-locale="en-US">',
    '  <info>',
    '    <title>Journal of Made-up Results</title>',
    '    <link href="http://www.zotero.org/styles/apa" rel="independent-parent"/>',
    '  </info>',
    '</style>'), file.path(r, "dependent", "made-up-results.csl"))
  writeLines("<html><body>Not Found</body></html>", file.path(r, "broken.csl"))
  r
}

project <- function() {
  p <- tempfile("paper")
  suppressMessages(create_paper(p, git = FALSE))
  p
}

test_that("an independent style lands in references_styles/", {
  p <- project()
  r <- fake_repo()
  expect_message(out <- add_journal("APA.csl", path = p, repo = r),
                 "Added references_styles/apa.csl \\(American Psychological")
  expect_identical(out, file.path(normalizePath(p), "references_styles", "apa.csl"))
  expect_identical(readLines(out), readLines(file.path(r, "apa.csl")))
})

test_that("a dependent style is saved with its parent's rules, and says so", {
  p <- project()
  r <- fake_repo()
  said <- capture_messages(out <- add_journal("made-up-results", path = p,
                                              repo = r))
  expect_true(any(grepl("parent, 'apa'", said)))
  expect_identical(basename(out), "made-up-results.csl")
  expect_identical(readLines(out), readLines(file.path(r, "apa.csl")))
})

test_that("what is not a style is refused, and nothing is written", {
  p <- project()
  r <- fake_repo()
  expect_error(add_journal("broken", path = p, repo = r), "No style called 'broken'")
  expect_error(add_journal("nope", path = p, repo = r), "No style called 'nope'")
  expect_error(add_journal("no such", path = p, repo = r), "style name")
  expect_error(add_journal("apa", path = tempfile(), repo = r),
               "not an easypaper project")
  expect_error(add_journal("apa", path = p, repo = r, overwrite = "yes"),
               "TRUE or FALSE")
  expect_false(any(c("broken.csl", "nope.csl") %in%
                     list.files(file.path(p, "references_styles"))))
})

test_that("a style already there is kept unless overwrite = TRUE", {
  p <- project()
  r <- fake_repo()
  dest <- suppressMessages(add_journal("apa", path = p, repo = r))
  writeLines("edited by hand", dest)
  expect_message(add_journal("apa", path = p, repo = r), "already")
  expect_identical(readLines(dest), "edited by hand")
  suppressMessages(add_journal("apa", path = p, repo = r, overwrite = TRUE))
  expect_identical(readLines(dest), readLines(file.path(r, "apa.csl")))
})

test_that("update_project() leaves a style added this way alone", {
  p <- project()
  r <- fake_repo()
  dest <- suppressMessages(add_journal("apa", path = p, repo = r))
  plan <- suppressMessages(update_project(p, dry_run = TRUE))
  expect_false("references_styles/apa.csl" %in% plan$file)
})

test_that("the live repository serves a style", {
  skip_on_cran()
  online <- tryCatch({
    con <- url(paste0(.csl_repo, "/apa.csl"), open = "rb")
    close(con)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  skip_if_not(online, "no network")

  p <- project()
  expect_message(out <- add_journal("apa", path = p), "Added references_styles/apa.csl")
  expect_true(.csl_is_style(readLines(out, warn = FALSE)))
})
