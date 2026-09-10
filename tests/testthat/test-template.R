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

test_that("a render never merges the manuscript with its supplement", {
  # Merging means handing both documents to pandoc, which rebuilds them and
  # loses every column width: the tables reached Word with their headings
  # broken across two lines. One document per section, always.
  code <- gsub("[[:space:]]+", " ", paste(readLines(tpl("make.R"), warn = FALSE),
                                          collapse = " "))
  expect_no_match(code, ".merge_documents", fixed = TRUE)
  # The word on its own, so strsplit() in another helper is not a false alarm.
  expect_no_match(code, "(?<![[:alpha:]])split", perl = TRUE)
  for (fn in c("render_docx", "render_pdf")) {
    f <- Filter(function(x) {
      is.call(x) && identical(as.character(x[[1]]), "<-") &&
        identical(as.character(x[[2]]), fn)
    }, as.list(parse(tpl("make.R"), keep.source = FALSE)))
    expect_length(f, 1L)
    expect_false("split" %in% names(formals(eval(f[[1]][[3]]))))
  }
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

test_that("a flextable keeps its natural width and is never stretched", {
  # Quarto wraps every captioned table in a container 5.5 inches wide, and the
  # helper used to force the table to exactly 6. A 6 inch table inside a 5.5
  # inch cell came out misaligned in the .docx and correct in the .pdf, from
  # the same code. autofit() alone is the width that works; this only brings
  # back a table too wide for the page.
  e <- new.env()
  exprs <- as.list(parse(tpl("R/setup.R"), keep.source = FALSE))
  fn <- Filter(function(x) {
    is.call(x) && identical(as.character(x[[1]]), "<-") &&
      identical(as.character(x[[2]]), "fit_flextable_to_page")
  }, exprs)
  expect_length(fn, 1L)
  eval(fn[[1]], envir = e)
  expect_identical(formals(e$fit_flextable_to_page)$pgwidth, 5.5)

  skip_if_not_installed("flextable")
  narrow <- flextable::flextable(data.frame(a = 1:2, b = c("x", "y")))
  # What the helper returns is what autofit() returns: nothing is stretched.
  expect_equal(dim(e$fit_flextable_to_page(narrow))$widths,
               dim(flextable::autofit(narrow))$widths)

  wide <- flextable::flextable(
    as.data.frame(matrix(strrep("long text here ", 3), 2, 8)))
  expect_gt(sum(dim(flextable::autofit(wide))$widths), 5.5)
  expect_equal(sum(dim(e$fit_flextable_to_page(wide))$widths), 5.5)
})

test_that("the Word templates draw no rule around a table", {
  # Quarto wraps every captioned float in a container table, and the template's
  # `Table` style used to give it a thick rule above and below. Those are the
  # bars that appeared around every table and figure in the .docx. Every table
  # in the project is a flextable now and draws its own rules.
  for (f in list.files(tpl("format"), "[.]docx$", full.names = TRUE)) {
    con <- unz(f, "word/styles.xml")
    xml <- paste(readLines(con, warn = FALSE), collapse = "")
    style <- regmatches(xml, regexpr('<w:style[^>]*w:styleId="Table".*?</w:style>',
                                     xml, perl = TRUE))
    expect_length(style, 1L)
    expect_no_match(style, 'w:val="single"', fixed = TRUE, info = basename(f))
  }
})

test_that("every table in the template is a flextable", {
  # One engine, so they all come out with the same font, the same rules and
  # columns measured from their content. knitr::kable() hands pandoc a plain
  # markdown table and pandoc gives it columns of equal width.
  qmd <- list.files(tpl("_sections"), "[.]qmd$", full.names = TRUE)
  for (f in c(qmd, tpl("manuscript.qmd"), tpl("supplementary.qmd"))) {
    txt <- readLines(f, warn = FALSE)
    code <- txt[!grepl("^\\s*#", txt)]
    expect_false(any(grepl("kable(", code, fixed = TRUE)), info = basename(f))
  }
})

test_that("no render carries a date", {
  # A manuscript is dated by the journal, not by the day you rendered it, and
  # a date on a draft you circulate only misleads.
  y <- rmarkdown::yaml_front_matter(tpl("manuscript.qmd"))
  expect_null(y$date)
  expect_null(y[["date-format"]])
})

test_that("the supplement names its authors, and a blinded one names nobody", {
  # The authors go in the title block, which puts them under the title and
  # above the affiliations the body includes. The blinded supplement travels
  # with the anonymised manuscript, so it carries neither: the affiliations
  # identify you as surely as the names, and they used to travel.
  fn <- Filter(function(x) {
    is.call(x) && identical(as.character(x[[1]]), "<-") &&
      identical(as.character(x[[2]]), "render_supplementary")
  }, as.list(parse(tpl("make.R"), keep.source = FALSE)))
  expect_length(fn, 1L)
  expect_identical(formals(eval(fn[[1]][[3]]))$blinded, FALSE)

  code <- gsub("[[:space:]]+", " ", paste(vapply(
    as.list(parse(tpl("R/submission.R"), keep.source = FALSE)),
    function(e) paste(deparse(e), collapse = " "), character(1)), collapse = " "))
  # make_submission() passes its own blinding through to the supplement.
  expect_match(code, "blinded = blinded", fixed = TRUE)

  # And the wrapper drops the affiliations when blinded.
  bs <- Filter(function(x) {
    is.call(x) && identical(as.character(x[[1]]), "<-") &&
      identical(as.character(x[[2]]), ".build_supplementary")
  }, as.list(parse(tpl("R/submission.R"), keep.source = FALSE)))
  expect_length(bs, 1L)
  expect_identical(formals(eval(bs[[1]][[3]]))$blinded, FALSE)
})

test_that("the title page names its sections the way the manuscript does", {
  # They used to be bold labels ending in a colon, with names of their own,
  # and the manuscript had sections of the same meaning under other headings.
  # One set of names, written once.
  tp <- readLines(tpl("title_page.qmd"), warn = FALSE)
  ms <- readLines(tpl("manuscript.qmd"), warn = FALSE)
  e <- new.env()
  for (x in as.list(parse(tpl("R/submission.R"), keep.source = FALSE))) {
    if (is.call(x) && identical(as.character(x[[1]]), "<-") &&
        as.character(x[[2]]) %in% c("BLINDED_SECTIONS", ".section_block",
                                    ".drop_sections")) eval(x, envir = e)
  }
  expect_length(e$BLINDED_SECTIONS, 4L)
  for (h in e$BLINDED_SECTIONS) {
    expect_true(any(trimws(tp) == paste("#", h)), info = h)
    expect_true(any(trimws(ms) == paste("#", h)), info = h)
  }
  # No heading on that page ends in a colon.
  expect_false(any(grepl("^#.*:\\s*$", tp)))
})

test_that("a blinded submission moves the identifying sections, and only those", {
  e <- new.env()
  for (x in as.list(parse(tpl("R/submission.R"), keep.source = FALSE))) {
    if (is.call(x) && identical(as.character(x[[1]]), "<-") &&
        as.character(x[[2]]) %in% c("BLINDED_SECTIONS", ".section_block",
                                    ".drop_sections")) eval(x, envir = e)
  }
  l <- c("# One", "text one", "", "# Two", "text two", "", "# Three", "t3")
  expect_identical(e$.section_block(l, "Two"), c("# Two", "text two"))
  expect_identical(e$.section_block(l, "Nowhere"), character(0))
  expect_identical(e$.drop_sections(l, "Two"),
                   c("# One", "text one", "", "# Three", "t3"))

  # The title page lists them in the order they come out in.
  expect_identical(e$BLINDED_SECTIONS[4], "Data availability statement")

  code <- gsub("[[:space:]]+", " ", paste(vapply(
    as.list(parse(tpl("R/submission.R"), keep.source = FALSE)),
    function(x) paste(deparse(x), collapse = " "), character(1)), collapse = " "))
  expect_match(code, ".drop_sections(txt, BLINDED_SECTIONS)", fixed = TRUE)
  expect_match(code, ".build_title_page(blinded = blinded)", fixed = TRUE)
})

test_that("the keywords are a section of the manuscript, written once", {
  # They used to be an empty `**Keywords:**` label on the title page while the
  # YAML carried the real ones, which is two places to keep in step. The
  # section prints what the YAML holds, and that is what the deposit's
  # metadata reads too.
  ms <- readLines(tpl("manuscript.qmd"), warn = FALSE)
  expect_true(any(trimws(ms) == "# Keywords"))
  expect_true(any(grepl("yaml_front_matter(knitr::current_input())$keywords",
                        ms, fixed = TRUE)))
  expect_false(is.null(rmarkdown::yaml_front_matter(tpl("manuscript.qmd"))$keywords))
  # And it is not one of the sections a blinded submission moves away.
  expect_false(any(trimws(readLines(tpl("title_page.qmd"), warn = FALSE)) ==
                     "# Keywords"))
})

test_that("the title page carries no leftover empty fields", {
  # Running head, word counts, ORCID and funding were bold labels with nothing
  # after them, on a page nobody fills in: they reached the journal blank.
  tp <- paste(readLines(tpl("title_page.qmd"), warn = FALSE), collapse = "\n")
  for (f in c("Running head", "Word count", "Supplementary items",
              "ORCID", "Funding", "Keywords")) {
    expect_no_match(tp, f, fixed = TRUE, info = f)
  }
})

test_that("the placeholders say what to replace, and the code knows them", {
  # A new project opens on its own placeholders, so they have to read as
  # instructions rather than as somebody else's paper.
  y <- rmarkdown::yaml_front_matter(tpl("manuscript.qmd"))
  expect_identical(y$title, "Manuscript title here")
  expect_identical(vapply(y$author, function(a) a$name, character(1)),
                   c("Author1^1,\\*^", "Author2^2^"))
  expect_identical(unlist(y$keywords), c("keyword1", "keyword2", "keyword3"))
  expect_identical(rmarkdown::yaml_front_matter(tpl("title_page.qmd"))$title,
                   y$title)

  # make.R warns while they are still there, so its list has to match: the
  # names with their affiliation marks stripped.
  e <- new.env()
  for (x in as.list(parse(tpl("make.R"), keep.source = FALSE))) {
    if (is.call(x) && identical(as.character(x[[1]]), "<-") &&
        identical(as.character(x[[2]]), "TEMPLATE_AUTHORS")) eval(x, envir = e)
  }
  bare <- trimws(gsub("[\\\\*,]+$", "",
                      trimws(gsub("\\^[^^]*\\^", "",
                                  vapply(y$author, function(a) a$name, character(1))))))
  expect_identical(e$TEMPLATE_AUTHORS, bare)
})

test_that("the supplement opens with a reference to the paper it belongs to", {
  # It is downloaded on its own from the journal's site, with nothing around
  # it to say what it supports. The subtitle used to be the bare title.
  code <- gsub("[[:space:]]+", " ", paste(vapply(
    as.list(parse(tpl("make.R"), keep.source = FALSE)),
    function(e) paste(deparse(e), collapse = " "), character(1)), collapse = " "))
  expect_match(code, ".manuscript_reference(journal, blinded = blinded)",
               fixed = TRUE)
  expect_match(code, "list(subtitle = reference)", fixed = TRUE)

  # The journal's name comes from its own style file, not from the slug.
  e <- new.env()
  for (x in as.list(parse(tpl("make.R"), keep.source = FALSE))) {
    if (is.call(x) && identical(as.character(x[[1]]), "<-") &&
        identical(as.character(x[[2]]), ".journal_name")) eval(x, envir = e)
  }
  e$here <- function(...) file.path(tpl(), ...)
  expect_identical(e$.journal_name("myrmecological-news"), "Myrmecological News")
  expect_identical(e$.journal_name("no-such-style"), "no-such-style")
})

test_that("the supplement carries no address, and names authors as a reference does", {
  # The reference above already says whose paper it is; the affiliations and
  # the correspondence line under it were an address nobody asked for.
  sup <- paste(readLines(tpl("supplementary.qmd"), warn = FALSE), collapse = "\n")
  expect_no_match(sup, "0_authors", fixed = TRUE)

  e <- new.env()
  for (x in as.list(parse(tpl("make.R"), keep.source = FALSE))) {
    if (is.call(x) && identical(as.character(x[[1]]), "<-") &&
        identical(as.character(x[[2]]), ".reference_name")) eval(x, envir = e)
  }
  expect_identical(e$.reference_name("Ada Lovelace"), "Lovelace, A.")
  expect_identical(e$.reference_name("Daniel Sanchez-Garcia"), "Sanchez-Garcia, D.")
  expect_identical(e$.reference_name("Ada Byron Lovelace"), "Lovelace, A. B.")
  # One word is left as it is rather than turned into an initial of nothing.
  expect_identical(e$.reference_name("Prince"), "Prince")
})
