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

test_that("the project declares the formats the supplement can be asked for", {
  # .build_supplementary() copies these into the wrapper it renders. Without
  # them Quarto falls back on its own PDF defaults -- KOMA-Script and lualatex
  # -- which is a different document class from the manuscript's and one a lean
  # LaTeX install does not carry: the render dies with "scrartcl.cls not found".
  y <- yaml::read_yaml(tpl("_quarto.yml"))
  expect_true(all(c("docx", "pdf") %in% names(y$format)))
})

test_that("every Word template the code asks for actually travels", {
  # The cover letter names its own template from R, not from a .qmd, so no
  # other test would notice it missing until a submission was being built.
  src  <- readLines(tpl("R/submission.R"), warn = FALSE)
  refs <- regmatches(src, regexpr("(?<=reference-doc: )[^\"]+", src, perl = TRUE))
  expect_gt(length(refs), 0L)
  for (r in trimws(refs)) expect_true(file.exists(tpl(r)), info = r)
})

test_that("the deposit's metadata is read without dataspice's stray warning", {
  # dataspice writes its scaffold with no final newline, and read.csv warns
  # about that on every render until the file has been written back once. The
  # muffling is one helper, and a sync from the working project that lost it
  # would put the warning back into every render log.
  exprs <- as.list(parse(tpl("make.R")))
  assigned <- function(fn) {
    Filter(function(x) {
      is.call(x) && identical(as.character(x[[1]]), "<-") &&
        identical(as.character(x[[2]]), fn)
    }, exprs)
  }
  expect_length(assigned(".read_meta"), 1L)

  sm <- assigned("sync_metadata")
  expect_length(sm, 1L)
  code <- paste(deparse(sm[[1]]), collapse = "\n")
  expect_match(code, ".read_meta(", fixed = TRUE)
  expect_no_match(code, "utils::read.csv", fixed = TRUE)

  # And the helper really does muffle that warning, and only that one.
  e <- new.env()
  eval(assigned(".read_meta")[[1]], envir = e)
  f <- tempfile(fileext = ".csv")
  cat("a,b\n1,2", file = f)                      # no final newline
  expect_no_warning(d <- e$.read_meta(f, colClasses = "character"))
  expect_identical(d$a, "1")

  # And the muffling is targeted: any other warning from the same read still
  # reaches you. Invalid bytes read as UTF-8 are one such warning, and the
  # check only runs where that warning actually happens.
  bad <- tempfile(fileext = ".csv")
  writeBin(as.raw(c(0x61, 0x2c, 0x62, 0x0a, 0xff, 0x2c, 0x32, 0x0a)), bad)
  warns <- function(expr) {
    got <- FALSE
    withCallingHandlers(try(expr, silent = TRUE),
                        warning = function(w) {
                          got <<- TRUE
                          invokeRestart("muffleWarning")
                        })
    got
  }
  skip_if_not(warns(utils::read.csv(bad, fileEncoding = "UTF-8")),
              "this platform does not warn on invalid UTF-8")
  expect_warning(e$.read_meta(bad, fileEncoding = "UTF-8"))
})

test_that("renv's snapshot report does not flood the render log", {
  # renv prints straight to the console rather than through message(), so the
  # suppressMessages() around it never caught anything: a first render dumped
  # the whole resolved library, a hundred lines, over the log. Both snapshot
  # sites set renv's own switch for that.
  for (f in c("make.R", "R/submission.R")) {
    txt <- paste(readLines(tpl(f), warn = FALSE), collapse = "\n")
    expect_match(txt, "renv::snapshot(", fixed = TRUE, info = f)
    expect_match(txt, "renv.verbose", fixed = TRUE, info = f)
  }
})

test_that("the blinded main text keeps the title and drops the authors", {
  # A journal expects the title at the head of the anonymised manuscript, and
  # it names nobody. Stripping it together with the author block sent out a
  # main text that opened straight at the Abstract.
  exprs <- as.list(parse(tpl("R/submission.R")))
  fn <- Filter(function(x) {
    is.call(x) && identical(as.character(x[[1]]), "<-") &&
      identical(as.character(x[[2]]), ".build_main_text")
  }, exprs)
  expect_length(fn, 1L)

  code <- gsub("[[:space:]]+", " ", paste(deparse(fn[[1]]), collapse = " "))
  drop <- regmatches(code, regexpr("for \\(nm in c\\([^)]*\\)\\) yml\\[\\[nm\\]\\] <- NULL",
                                   code))
  expect_length(drop, 1L)
  expect_match(drop, '"author"', fixed = TRUE)
  expect_no_match(drop, '"title"', fixed = TRUE)
})

test_that("split = TRUE still renders the supplement, it only skips the merge", {
  # Asking for two files and silently getting one is the kind of thing you
  # discover on the day you submit: .render() used to render the supplement
  # only when it was about to merge it back in, so render_docx(split = TRUE)
  # wrote the main text alone while the documentation promised two.
  exprs <- as.list(parse(tpl("make.R")))
  fn <- Filter(function(x) {
    is.call(x) && identical(as.character(x[[1]]), "<-") &&
      identical(as.character(x[[2]]), ".render")
  }, exprs)
  expect_length(fn, 1L)
  expect_true("supplement" %in% names(formals(eval(fn[[1]][[3]]))))

  code <- gsub("[[:space:]]+", " ", paste(deparse(fn[[1]]), collapse = " "))
  expect_match(code, "if (supplement)", fixed = TRUE)
  expect_match(code, "if (!split) produced <- .merge_documents", fixed = TRUE)
})

test_that("the deliverable builders render the supplement exactly once", {
  # make_submission() and make_preprint() render it themselves, with their own
  # subset of files and their own labelled names. Without supplement = FALSE
  # they would now get a second, unlabelled copy from .render().
  # Parsed, not grepped: deparse drops the comments, which mention the
  # argument too and would be counted as calls.
  code <- gsub("[[:space:]]+", " ", paste(vapply(
    as.list(parse(tpl("R/submission.R"), keep.source = FALSE)),
    function(e) paste(deparse(e), collapse = " "), character(1)),
    collapse = " "))
  count <- function(pat) {
    length(regmatches(code, gregexpr(pat, code, fixed = TRUE))[[1]])
  }
  expect_identical(count("supplement = FALSE"), 2L)
  expect_identical(count("render_supplementary("), 2L)
})

test_that("a flextable is fitted to its container, not to a fixed width", {
  # Quarto wraps every captioned table in a container 5.5 inches wide, and the
  # helper used to hand Word a table of exactly 6. A 6 inch table inside a 5.5
  # inch cell came out misaligned in the .docx and correct in the .pdf, from
  # the same code. Filling the container is what makes the two agree.
  e <- new.env()
  exprs <- as.list(parse(tpl("R/setup.R"), keep.source = FALSE))
  fn <- Filter(function(x) {
    is.call(x) && identical(as.character(x[[1]]), "<-") &&
      identical(as.character(x[[2]]), "fit_flextable_to_page")
  }, exprs)
  expect_length(fn, 1L)
  eval(fn[[1]], envir = e)

  # No width by default: the table takes whatever it is given.
  expect_null(formals(e$fit_flextable_to_page)$pgwidth)
  code <- gsub("[[:space:]]+", " ", paste(deparse(fn[[1]]), collapse = " "))
  expect_match(code, 'layout = "autofit"', fixed = TRUE)
  expect_match(code, "width = 1", fixed = TRUE)
  # And the escape hatch for a table that must be a fixed size still works.
  expect_match(code, "flextable::width(", fixed = TRUE)
})
