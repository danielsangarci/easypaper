# The template is a copy of a working project, kept in sync by hand. These
# tests are the guard against that copy drifting: a renamed section, a .csl
# that did not travel, a Word template left behind. They read what actually
# ships, not the sources.

tpl <- function(...) file.path(system.file("template", package = "easypaper"), ...)

test_that("every include points at a file that exists", {
  for (f in c("manuscript.qmd", "supplementary.qmd", "title_page.qmd")) {
    l <- readLines(tpl(f), warn = FALSE)
    inc <- regmatches(l, regexpr("(?<=\\{\\{< include )[^ >]+", l, perl = TRUE))
    expect_gt(length(inc), 0L)
    for (i in inc) {
      expect_true(file.exists(tpl(i)), info = paste(f, "->", i))
    }
  }
})

test_that("_quarto.yml points at files that exist", {
  y <- yaml::read_yaml(tpl("_quarto.yml"))

  for (f in y$project$render) expect_true(file.exists(tpl(f)), info = f)
  expect_true(file.exists(tpl(y$csl)), info = y$csl)
  for (b in unlist(y$bibliography)) expect_true(file.exists(tpl(b)), info = b)

  ref <- y$format$docx$`reference-doc`
  expect_true(file.exists(tpl(ref)), info = ref)
  # The supplement uses its own Word template, named in supplementary.qmd.
  sup <- yaml::read_yaml(text = paste(
    readLines(tpl("supplementary.qmd"), warn = FALSE)[
      seq(2, which(readLines(tpl("supplementary.qmd"), warn = FALSE) == "---")[2] - 1)],
    collapse = "\n"))$format$docx$`reference-doc`
  expect_true(file.exists(tpl(sup)), info = sup)
})

test_that("make.R can find what it sources", {
  l <- readLines(tpl("make.R"), warn = FALSE)
  src <- regmatches(l, regexpr('(?<=source\\(here\\(")[^"]+', l, perl = TRUE))
  expect_gt(length(src), 0L)
  for (f in src) expect_true(file.exists(tpl(f)), info = f)
})

test_that("the supplementary convention still resolves", {
  # make.R finds the supplement by name; if the file is ever renamed out of
  # this pattern, the submission silently ships without it.
  expect_gt(length(list.files(tpl("_sections"), "^8.*suppl.*[.]qmd$")), 0L)
})

test_that("no generated or dead files travel in the template", {
  for (d in c("output", "submission", "cache", "figures", ".quarto")) {
    expect_false(dir.exists(tpl(d)), info = d)
  }
  for (f in c("renv.lock", ".DS_Store", ".Rhistory",
              "format/scholarly-metadata.lua", "format/author-info-blocks.lua",
              "format/template2.docx")) {
    expect_false(file.exists(tpl(f)), info = f)
  }
  # A .gitignore would not survive R CMD build; it must travel renamed.
  expect_true(file.exists(tpl("gitignore")))
})

test_that("the template ships both ways out of the project", {
  # A sync from the working project that dropped one of these would leave a
  # documented command with no code behind it.
  defined <- function(f, fn) {
    any(vapply(as.list(parse(tpl(f))), function(e) {
      is.call(e) && identical(as.character(e[[1]]), "<-") &&
        identical(as.character(e[[2]]), fn)
    }, logical(1)))
  }
  expect_true(defined("R/submission.R", "make_submission"))
  expect_true(defined("R/submission.R", "make_preprint"))
  expect_true(defined("make.R", "make_all"))
  expect_true(defined("make.R", "render_pdf"))
})

test_that("a supplementary float is found whichever way it is labelled", {
  # The bug this guards against: .suppl_numbering() once read only {#sfig-x}
  # divs, while check_crossrefs() also read chunk labels. A float labelled the
  # other way was numbered by one and ignored by the other, so the citation to
  # it survived unreplaced and reached the .docx as "?@sfig-x" -- with no
  # warning, because the label did exist.
  e <- new.env()
  sys.source(tpl("R/submission.R"), envir = e)

  f <- tempfile(fileext = ".qmd")
  writeLines(c("::: {#sfig-map}", "#| label: suppl-map", ":::",
               "```{r}", "#| label: sfig-model", "```",
               "::: {#stbl-raw}", ":::",
               "   #| label:   stbl-extra ",
               "As shown in @sfig-map and @stbl-raw."), f)

  # Both syntaxes, in order of appearance, and no citation mistaken for one.
  expect_identical(e$.suppl_label_ids(f),
                   c("sfig-map", "sfig-model", "stbl-raw", "stbl-extra"))
  expect_true(e$.suppl_is_floats(f))
})
