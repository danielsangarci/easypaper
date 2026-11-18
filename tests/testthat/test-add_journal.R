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
    '    <link href="http://www.zotero.org/styles/apa" rel="self"/>',
    '    <category citation-format="author-date"/>',
    '    <category field="psychology"/>',
    '    <summary>Author-date system of the APA Publication Manual</summary>',
    '  </info>',
    '  <citation><layout><text variable="title"/></layout></citation>',
    '  <bibliography><layout><text variable="title"/></layout></bibliography>',
    '</style>'), file.path(r, "apa.csl"))
  writeLines(c(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<style xmlns="http://purl.org/net/xbiblio/csl" version="1.0" default-locale="en-US">',
    '  <info>',
    '    <title>Journal of Made-up Results</title>',
    '    <id>http://www.zotero.org/styles/made-up-results</id>',
    '    <link href="http://www.zotero.org/styles/made-up-results" rel="self"/>',
    '    <link href="http://www.zotero.org/styles/apa" rel="independent-parent"/>',
    '    <link href="https://made-up.example.org/author-guidelines" rel="documentation"/>',
    '    <category citation-format="author-date"/>',
    '    <category field="biology"/>',
    '    <issn>1234-5678</issn>',
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

test_that("an independent style lands in references/, beside the .bib", {
  p <- project()
  r <- fake_repo()
  expect_message(out <- add_journal("APA.csl", path = p, repo = r),
                 "Added references/apa.csl \\(American Psychological")
  expect_identical(out, file.path(normalizePath(p, winslash = "/"), "references",
                                   "apa.csl"))
  expect_true("apa" %in% list_journals(p))
  expect_identical(readLines(out), readLines(file.path(r, "apa.csl")))
})

test_that("with no path it works on the project set_paper() named", {
  # The way it is used: the project named once, from any folder in it.
  p <- project()
  r <- fake_repo()
  old <- setwd(file.path(p, "_sections"))
  on.exit(setwd(old), add = TRUE)
  expect_error(add_journal("apa", repo = r), "none is named")
  name_paper(".")
  suppressMessages(add_journal("apa", repo = r))
  expect_true(file.exists(file.path(p, "references", "apa.csl")))
  expect_true("apa" %in% list_journals())
})

test_that("a dependent style is saved with its parent's rules, and says so", {
  p <- project()
  r <- fake_repo()
  said <- capture_messages(out <- add_journal("made-up-results", path = p,
                                              repo = r))
  expect_true(any(grepl("parent, 'apa'", said)))
  expect_true(any(grepl("(Journal of Made-up Results)", said, fixed = TRUE)))
  expect_identical(basename(out), "made-up-results.csl")
  # The parent's rules, under the journal's own title: the title names the
  # journal in the submission folder and the cover letter.
  got <- readLines(out)
  apa <- readLines(file.path(r, "apa.csl"))
  expect_identical(grep("<title>", got, value = TRUE),
                   "    <title>Journal of Made-up Results</title>")
  expect_true(any(grepl("The rules of the 'apa' style", got, fixed = TRUE)))
  # The rules are the parent's, line for line.
  rules <- function(x) x[seq(grep("</info>", x, fixed = TRUE), length(x))]
  expect_identical(rules(got), rules(apa))
  # The card is the journal's: its identifier, its guidelines, its field and
  # its ISSN; the parent named as the template, its field and summary gone.
  info <- got[seq(grep("<info>", got, fixed = TRUE), grep("</info>", got, fixed = TRUE))]
  expect_true("    <id>http://www.zotero.org/styles/made-up-results</id>" %in% info)
  expect_true('    <link href="https://made-up.example.org/author-guidelines" rel="documentation"/>' %in% info)
  expect_true('    <link href="http://www.zotero.org/styles/apa" rel="template"/>' %in% info)
  expect_true('    <category field="biology"/>' %in% info)
  expect_true("    <issn>1234-5678</issn>" %in% info)
  expect_false(any(grepl("styles/apa</id>|psychology|<summary>|independent-parent", info)))
  expect_identical(sum(grepl('rel="self"', info)), 1L)
  # And the journal's locale, which a dependent style sets.
  expect_match(grep("<style ", got, value = TRUE), 'default-locale="en-US"', fixed = TRUE)
  expect_identical(in_project(p, .journal_name("made-up-results")),
                   "Journal of Made-up Results")
})

test_that("what is not a style is refused, and nothing is written", {
  p <- project()
  r <- fake_repo()
  expect_error(add_journal("broken", path = p, repo = r), "No style called 'broken'")
  expect_error(add_journal("nope", path = p, repo = r), "No style called 'nope'")
  expect_error(add_journal("no such", path = p, repo = r), "style name")
  empty <- tempfile("empty")
  dir.create(empty)
  expect_error(add_journal("apa", path = empty, repo = r),
               "No easypaper project")
  expect_error(add_journal("apa", path = p, repo = r, overwrite = "yes"),
               "TRUE or FALSE")
  expect_false(any(c("broken.csl", "nope.csl") %in%
                     list.files(file.path(p, "references"))))
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

test_that("the live repository serves a style", {
  skip_on_cran()
  online <- tryCatch({
    con <- url(paste0(.csl_repo, "/apa.csl"), open = "rb")
    close(con)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  skip_if_not(online, "no network")

  p <- project()
  expect_message(out <- add_journal("apa", path = p), "Added references/apa.csl")
  expect_true(.csl_is_style(readLines(out, warn = FALSE)))
})
