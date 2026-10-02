# How long the manuscript is: the counts a journal asks for, and its limits.

test_that("words are counted the way Word counts the rendered text", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  p <- new_project()
  in_project(p, {
    # Code, comments, shortcodes and markup are not words; inline R is one.
    expect_identical(.count_words(c(
      "We **studied** *Formica* ants.", "",
      "```{r}", "x <- 1  # not counted", "```", "",
      "<!-- a comment, not counted -->",
      "{{< pagebreak >}}",
      "There were `r 3 + 4` colonies.")), 8L)
    # A cross-reference is what it prints: "Figure 1".
    expect_identical(.count_words("See @fig-map and @tbl-raw."), 6L)
    # A citation is what the journal's style prints for it: (AKINO & al. 1999).
    expect_identical(.count_words("Ants live in colonies [@Akino1999]."), 8L)
    # List bullets and numbers are not words, as in Word.
    expect_identical(.count_words(c("- one item", "- two items", "",
                                    "1. three", "2) four")), 6L)
    expect_identical(.count_words(character(0)), 0L)
    expect_identical(.count_words("<!-- nothing -->"), 0L)
  })
})

test_that("manuscript_stats() counts what a submission form asks for", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  p <- new_project(title = "Chemical mimicry in ants")
  s <- file.path(p, "_sections")
  writeLines(c("Ants live in colonies.", "",
               "**Keywords:** ants, mimicry, parasitism"),
             file.path(s, "01_abstract.qmd"))
  writeLines("We studied ants [@Akino1999].", file.path(s, "02_introduction.qmd"))
  for (f in c("03_methods.qmd", "04.1_results1.qmd", "04.2_results2.qmd",
              "05_discussion.qmd")) {
    writeLines("Two words.", file.path(s, f))
  }
  # Not main text: the statements a blinded submission moves away.
  writeLines("We thank many many people here.", file.path(s, "06_acknowledgements.qmd"))

  st <- manuscript_stats(quiet = TRUE, path = p)
  expect_identical(names(st), c("title_chars", "title_chars_no_spaces",
                                "short_title_chars",
                                "short_title_chars_no_spaces", "abstract_words", "keywords", "main_words",
                                "main_words_with_refs", "references",
                                "figures", "tables",
                                "suppl_figures", "suppl_tables"))
  expect_identical(st[["title_chars"]], nchar("Chemical mimicry in ants"))
  expect_identical(st[["title_chars_no_spaces"]], nchar("Chemicalmimicryinants"))
  expect_identical(st[["short_title_chars"]], NA_integer_)
  expect_identical(st[["short_title_chars_no_spaces"]], NA_integer_)
  expect_identical(st[["abstract_words"]], 4L)   # the keywords line is not
  expect_identical(st[["keywords"]], 3L)
  # "We studied ants (AKINO & al. 1999)." + 4 sections of "Two words."
  expect_identical(st[["main_words"]], 7L + 4L * 2L)
  # With its reference list: the one entry cited, as the journal prints it.
  # The one entry the paper cites, and the words of its reference list.
  expect_identical(st[["references"]], 1L)
  refs <- in_project(p, .reference_list_words("Akino1999"))
  expect_gt(refs, 5L)
  expect_identical(st[["main_words_with_refs"]], st[["main_words"]] + refs)
  expect_identical(in_project(p, .reference_list_words(character(0))), 0L)
  # The floats of the paper, and of its supplement, apart.
  files <- in_project(p, c(.master(), .section_files()))
  sup   <- in_project(p, .suppl_files())
  main_lab  <- in_project(p, unique(.crossref_labels(setdiff(files, sup))))
  suppl_lab <- in_project(p, unique(.crossref_labels(sup)))
  expect_identical(st[["figures"]], sum(startsWith(main_lab, "fig-")))
  expect_identical(st[["tables"]], sum(startsWith(main_lab, "tbl-")))
  expect_identical(st[["suppl_figures"]], sum(startsWith(suppl_lab, "sfig-")))
  expect_identical(st[["suppl_tables"]], sum(startsWith(suppl_lab, "stbl-")))
  expect_gt(st[["figures"]] + st[["suppl_figures"]], 0L)

  # Printed one to a line: what, the number right-aligned, and its unit.
  msg <- paste(capture.output(manuscript_stats(path = p), type = "message"),
               collapse = "\n")
  l <- strsplit(msg, "\n")[[1]]
  expect_identical(l[1], "Manuscript summary")
  body <- l[-1]
  expect_length(body, 11L)
  expect_match(body[1], "^  Title +24 characters$")
  expect_match(body[2], "^  Title, without spaces +21 characters$")
  expect_match(body[3], "^  Abstract +4 words$")
  expect_match(body[4], "^  Keywords +3$")
  expect_match(body[5], "^  Main text +15 words$")
  expect_match(body[6], sprintf("^  Main text \\+ references +%d words$", 15L + refs))
  expect_match(body[7], "^  References +1$")
  expect_match(body[10], "^  Supplementary figures +[0-9]+$")
  expect_false(any(grepl("Short title", body)))
  # The numbers end in one column.
  ends <- vapply(regmatches(body, regexpr("^.*[0-9]", body)), nchar, 1L)
  expect_identical(length(unique(ends)), 1L)
})

test_that("the main text leaves out the statements, whatever they are called", {
  expect_identical(
    in_project(new_project(), .not_main_text(c(
      "Introduction", "Material and Methods", "Results", "Discussion",
      "Acknowledgements", "Acknowledgments", "Funding",
      "CRediT authorship contribution statement", "Author contributions",
      "Conflict of Interest Statement", "Competing interests",
      "Data availability statement", "Data accessibility", "Ethics",
      "Keywords"))),
    c(rep(FALSE, 4L), rep(TRUE, 11L)))
  # Even when a project takes them off blinded-sections:.
  p <- new_project()
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(y[!grepl("^    - (Acknowledgements|Data availability)", y)],
             file.path(p, "_quarto.yml"))
  writeLines("We thank many many people here.",
             file.path(p, "_sections", "06_acknowledgements.qmd"))
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  expect_identical(manuscript_stats(quiet = TRUE, path = p)[["main_words"]], 0L)
})

test_that("every render and every make prints the length, once", {
  # At the end of each render_*() and make_*(); render_all() and the deliverables
  # hold back the renders they call and print it themselves, when done.
  for (fn in list(render_docx, render_pdf, render_html, render_supplementary)) {
    expect_match(code_of(fn), ".report_length() invisible(", fixed = TRUE)
  }
  for (fn in list(render_all, make_submission, make_preprint)) {
    expect_match(code_of(fn), "outer <- .batch()", fixed = TRUE)
    expect_match(code_of(fn), "if (outer) .report_length(force = TRUE)",
                 fixed = TRUE)
  }
  expect_no_match(code_of(.render), "report_length", fixed = TRUE)

  p <- new_project()
  printed <- function(expr) {
    length(grep("Manuscript summary",
                capture.output(expr, type = "message"), fixed = TRUE))
  }
  in_project(p, {
    expect_identical(printed(.report_length()), 1L)
    nested <- function() {
      outer <- .batch()
      a <- printed(.report_length())             # a render inside: silent
      inner <- (function() .batch())()            # a make inside: not outer
      b <- if (outer) printed(.report_length(force = TRUE)) else 0L
      c(a, inner, outer, b)
    }
    expect_identical(nested(), c(0L, 0L, 1L, 1L))
    # The hold ends with the call, error or not.
    expect_null(.ep$batch)
    try((function() { .batch(); stop("boom") })(), silent = TRUE)
    expect_null(.ep$batch)
    expect_identical(printed(.report_length()), 1L)
  })

  # Nothing is checked, and nothing is written on the title page or in the
  # checklist.
  expect_no_match(code_of(.build_title_page), "stats", fixed = TRUE)
  f <- tempfile(fileext = ".md")
  .write_checklist(f, "Oryx", "Oryx")
  expect_false(any(grepl("manuscript_stats", readLines(f), fixed = TRUE)))
  # A count that fails is never worth a failed render.
  q <- new_project()
  expect_null(suppressMessages(in_project(q, {
    file.remove(file.path(q, "manuscript.qmd"))
    .report_length()
  })))
})

test_that("the summary counts the short title when there is one", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  p <- new_project(title = "Chemical mimicry in ants")
  ms <- readLines(file.path(p, "manuscript.qmd"))
  writeLines(sub("^# short-title: .*$", 'short-title: "Mimicry in ants"', ms),
             file.path(p, "manuscript.qmd"))
  st <- manuscript_stats(quiet = TRUE, path = p)
  expect_identical(st[["short_title_chars"]], nchar("Mimicry in ants"))
  expect_identical(st[["short_title_chars_no_spaces"]], nchar("Mimicryinants"))
  msg <- capture.output(manuscript_stats(path = p), type = "message")
  i <- grep("Short title", msg)
  expect_length(i, 2L)
  expect_match(msg[i[1]], "^  Short title +15 characters$")
  expect_match(msg[i[2]], "^  Short title, without spaces +13 characters$")
  expect_identical(i, grep("Title, without spaces", msg) + 1:2)
})
