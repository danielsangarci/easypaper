# The template is a copy of a working project, kept in sync by hand, and the
# functions that build it live in the package. These tests guard both: that
# what ships is sound -- a renamed section, a style that did not travel -- and
# that the functions do to a real project what they promise.

test_that("every include points at a file that exists", {
  for (f in c("manuscript.qmd", "supplementary.qmd")) {
    l <- readLines(tpl(f), warn = FALSE)
    inc <- regmatches(l, regexpr("(?<=\\{\\{< include )[^ >]+", l, perl = TRUE))
    # supplementary.qmd includes nothing: each render puts its section in.
    if (f == "manuscript.qmd") expect_gt(length(inc), 0L)
    for (i in inc) {
      expect_true(file.exists(tpl(i)), info = paste(f, "->", i))
    }
  }
})

test_that("_quarto.yml points at files that exist", {
  y <- yaml::read_yaml(tpl("_quarto.yml"))
  for (f in y$project$render) expect_true(file.exists(tpl(f)), info = f)
  # The journal is declared by the manuscript, not by the project.
  expect_null(y$csl)
  csl <- rmarkdown::yaml_front_matter(tpl("manuscript.qmd"))$csl
  expect_true(file.exists(tpl(csl)), info = csl)
  expect_match(csl, "^references/")
  for (b in unlist(y$bibliography)) expect_true(file.exists(tpl(b)), info = b)
  # The Word templates come from the package: nothing in the project names one.
  for (f in c("_quarto.yml", "supplementary.qmd")) {
    expect_false(any(grepl("reference-doc", readLines(tpl(f), warn = FALSE))),
                 info = f)
  }
})

test_that("the template carries the paper and no build logic", {
  # The functions that render and assemble a project live in the package.
  # A sync from a working project that still carries them must not bring
  # them back.
  for (f in c("make.R", "run.R", "R/submission.R", "R/crossref_styles.R",
              "R/convert_data.R", "R/italicize_species.R", "R/renv_setup.R",
              "R/create_metadata.R", "R/trackdown.R")) {
    expect_false(file.exists(tpl(f)), info = f)
  }
  expect_identical(list.files(tpl("R")), "setup.R")
  expect_false(dir.exists(tpl("format")))
  expect_false(dir.exists(tpl("references_styles")))
})

test_that("the supplementary convention still resolves", {
  # The supplement is found by name; if the file is ever renamed out of this
  # pattern, the submission silently ships without it.
  expect_gt(length(list.files(tpl("_sections"), SUPPL_FILE)), 0L)
})

test_that("no generated or dead files travel in the template", {
  for (d in c("output", "submission", "cache", "figures", ".quarto")) {
    expect_false(dir.exists(tpl(d)), info = d)
  }
  for (f in c("renv.lock", ".DS_Store", ".Rhistory")) {
    expect_false(file.exists(tpl(f)), info = f)
  }
  # A .gitignore would not survive R CMD build; it must travel renamed.
  expect_true(file.exists(tpl("gitignore")))
})

test_that("every command the project's README names is exported", {
  # The README is the first thing a co-author opens: a command in it that
  # does not exist is a dead end.
  l <- readLines(tpl("README.md"), warn = FALSE)
  code <- l[cumsum(grepl("^```", l)) %% 2 == 1 & !grepl("^```", l)]
  calls <- unlist(regmatches(code, gregexpr("^[a-z_]+(?=\\()", code, perl = TRUE)))
  calls <- setdiff(calls, c("library", "install.packages"))
  expect_gt(length(calls), 0L)
  for (fn in calls) expect_true(fn %in% getNamespaceExports("easypaper"), info = fn)
})

test_that("the settings block of the template is the defaults, written out", {
  y <- yaml::read_yaml(tpl("_quarto.yml"))$easypaper
  expect_identical(y[["blinded-sections"]], BLINDED_SECTIONS)
  expect_true(isTRUE(y[["italicize-species"]]))
  expect_length(y[["open-formats"]], 0L)
})

test_that("a supplementary float is found whichever way it is labelled", {
  # The bug this guards against: .suppl_numbering() once read only {#sfig-x}
  # divs, while check_crossrefs() also read chunk labels. A float labelled the
  # other way was numbered by one and ignored by the other, so the citation to
  # it survived unreplaced and reached the .docx as "?@sfig-x".
  f <- tempfile(fileext = ".qmd")
  writeLines(c("::: {#sfig-map}", "#| label: suppl-map", ":::",
               "```{r}", "#| label: sfig-model", "```",
               "::: {#stbl-raw}", ":::",
               "   #| label:   stbl-extra ",
               "As shown in @sfig-map and @stbl-raw."), f)
  expect_identical(.suppl_label_ids(f),
                   c("sfig-map", "sfig-model", "stbl-raw", "stbl-extra"))
  expect_true(.suppl_is_floats(f))
})

test_that("the project declares the formats the supplement can be asked for", {
  # .build_supplementary() copies these into the wrapper it renders. Without
  # them Quarto falls back on its own PDF defaults -- KOMA-Script and lualatex
  # -- and dies on a lean LaTeX install with "scrartcl.cls not found".
  y <- yaml::read_yaml(tpl("_quarto.yml"))
  expect_true(all(c("docx", "pdf") %in% names(y$format)))
})

test_that("the deposit's metadata is read without dataspice's stray warning", {
  # dataspice writes its scaffold with no final newline, and read.csv warns
  # about that on every render until the file has been written back once.
  expect_match(code_of(sync_metadata), ".read_meta(", fixed = TRUE)
  expect_no_match(code_of(sync_metadata), "utils::read.csv", fixed = TRUE)

  f <- tempfile(fileext = ".csv")
  cat("a,b\n1,2", file = f)                      # no final newline
  expect_no_warning(d <- .read_meta(f, colClasses = "character"))
  expect_identical(d$a, "1")

  # The muffling is targeted: any other warning from the same read still
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
  expect_warning(.read_meta(bad, fileEncoding = "UTF-8"))
})

test_that("renv's snapshot report does not flood the render log", {
  # renv prints straight to the console rather than through message(), so a
  # first render dumped the whole resolved library over the log. The one
  # place that snapshots sets renv's own switch for that, and every document
  # render and both deliverables go through it.
  expect_match(code_of(.record_env), "renv.verbose = FALSE", fixed = TRUE)
  for (fn in list(render_docx, render_pdf, render_supplementary,
                  make_submission, make_preprint)) {
    expect_match(code_of(fn), ".record_env()", fixed = TRUE)
    expect_no_match(code_of(fn), "renv::snapshot(", fixed = TRUE)
  }
  # render_html() is what you render after restoring an old environment: it
  # must never rewrite the record.
  expect_no_match(code_of(render_html), ".record_env()", fixed = TRUE)
})

test_that("the lockfile records easypaper, which no file of the project names", {
  p <- new_project()
  pkgs <- in_project(p, .analysis_packages())
  expect_true("easypaper" %in% pkgs)
})

test_that("the authors come out on one line, not one under another", {
  # Quarto gives each author of a list a paragraph of its own. A render is
  # handed them as one name, marks included; manuscript.qmd keeps its list.
  a <- list(list(name = "Ada Lovelace", affiliations = list("Univ X"),
                 email = "ada@example.org", corresponding = TRUE),
            list(name = "Alan Turing", affiliations = list("Inst Y")))
  expect_identical(.render_author(list(author = a)),
                   "Ada Lovelace^1,\\*^, Alan Turing^2^")
  # Names alone, however YAML writes them, still come out on one line.
  expect_identical(.render_author(list(author = c("Ada", "Alan"))), "Ada, Alan")
  expect_identical(.render_author(list(author = "Ada")), "Ada")
  expect_identical(.render_author(list(author = list(list(name = "Ada"),
                                                     list(name = "Alan")))),
                   "Ada, Alan")
  rich <- list(list(name = "Ada", orcid = "0000-0000-0000-0000"),
               list(name = "Alan"))
  expect_identical(.render_author(list(author = rich)), "Ada, Alan")
  expect_identical(.render_author(list(author = list(name = "Ada"))), "Ada")
  expect_null(.render_author(list()))

  p <- new_project(title = "Ants", authors = c("Ada Lovelace", "Alan Turing"))
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(sub("italicize-species: true", "italicize-species: false", y),
             file.path(p, "_quarto.yml"))
  f <- in_project(p, .build_main_text("journal-of-ecology", "default"))
  y <- rmarkdown::yaml_front_matter(f)
  expect_identical(y$author, "Ada Lovelace^1,\\*^, Alan Turing^2^")
  # Quarto's own affiliations would print them a second time.
  expect_null(y$affiliations)
  expect_length(rmarkdown::yaml_front_matter(file.path(p, "manuscript.qmd"))$author,
                2L)
  # The title page is handed the same line; and every render goes through the
  # copy, because the document's own front matter wins over metadata.
  expect_match(code_of(make_submission), "author = .render_author(own)",
               fixed = TRUE)
  expect_match(code_of(.render), ".build_main_text(journal, caption_style, fmt,",
               fixed = TRUE)
  expect_no_match(code_of(.render), "input = .master()", fixed = TRUE)
})

test_that("the marks are worked out from the affiliations each author names", {
  y <- list(
    author = list(
      list(name = "Ada", affiliations = "eco", corresponding = TRUE,
           email = "ada@example.org"),
      list(name = "Alan", affiliations = c("eco", "inst")),
      list(name = "Grace")),
    affiliations = list(
      list(id = "inst", name = "Institute Y, City"),
      list(id = "eco", name = "University X, City")))
  tb <- .title_block(y)
  # Numbered in the order the authors name them, not the order of the list.
  expect_identical(tb$line, "Ada^1,\\*^, Alan^1,2^, Grace")
  expect_identical(tb$lines, c("^1^ University X, City", "^2^ Institute Y, City",
                               "^\\*^ Correspondence: ada@example.org"))
  expect_length(tb$unused, 0L)

  # Reordering the authors renumbers them.
  y2 <- y; y2$author <- y$author[c(2, 1, 3)]
  expect_identical(.title_block(y2)$line, "Alan^1,2^, Ada^1,\\*^, Grace")
  expect_identical(.title_block(y2)$lines[1:2],
                   c("^1^ University X, City", "^2^ Institute Y, City"))

  # Written in place, with no list: the text is the affiliation, and two
  # authors naming the same one share its number.
  inplace <- list(author = list(
    list(name = "Ada", affiliations = "University X, City"),
    list(name = "Alan", affiliations = list(list(department = "Ecology",
                                                 name = "University X",
                                                 country = "Spain"))),
    list(name = "Grace", affiliations = "University X, City")))
  tb <- .title_block(inplace)
  expect_identical(tb$line, "Ada^1^, Alan^2^, Grace^1^")
  expect_identical(tb$lines, c("^1^ University X, City",
                               "^2^ Ecology, University X, Spain"))
  # `ref:`, Quarto's other way of pointing at one.
  byref <- y; byref$author[[2]]$affiliations <- list(list(ref = "inst"))
  expect_identical(.title_block(byref)$line, "Ada^1,\\*^, Alan^2^, Grace")

  # A typo in an id stops the render rather than print it.
  typo <- y; typo$author[[2]]$affiliations <- "ecco"
  expect_error(.title_block(typo), "`ecco`")
  # An affiliation nobody names is reported, and left out.
  extra <- y; extra$affiliations[[3]] <- list(id = "gone", name = "Nowhere")
  expect_identical(.title_block(extra)$unused, "gone")
  expect_false(any(grepl("Nowhere", .title_block(extra)$lines)))

  # Authors with no affiliation have nothing under them.
  expect_null(.title_block(list(author = c("Ada", "Alan")))$lines)
  # Quarto's other ways of writing a name.
  expect_identical(.person_name(list(name = list(given = "Ada",
                                                 family = "Lovelace"))),
                   "Ada Lovelace")
  expect_identical(.person_name(list(name = list(literal = "Prince"))), "Prince")
})

test_that("affiliations() prints the title block only where it belongs", {
  p <- new_project(authors = c("Ada Lovelace", "Alan Turing"))
  expect_output(out <- affiliations(p), "^\\^1\\^ Institution 1")
  expect_identical(out, paste(
    "^1^ Institution 1, Department, City, Country",
    "^2^ Institution 2, Department, City, Country",
    "^\\*^ Correspondence: correspondent@example.org", sep = "\n\n"))
  # The template's placeholders are reported by every render.
  expect_warning(in_project(p, .check_authors()), "template's affiliations")
  # The env variable is set only for as long as the render that set it.
  f <- function() { .rendering(); Sys.getenv("EASYPAPER_RENDER") }
  old <- Sys.getenv("EASYPAPER_RENDER", unset = NA)
  expect_identical(f(), "true")
  expect_identical(Sys.getenv("EASYPAPER_RENDER", unset = NA), old)
})

test_that("the blinded main text keeps the title and drops the authors", {
  # A journal expects the title at the head of the anonymised manuscript, and
  # it names nobody. Stripping it together with the author block sent out a
  # main text that opened straight at the Abstract.
  p <- new_project(title = "Ants", authors = c("Ada Lovelace", "Alan Turing"))
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(sub("italicize-species: true", "italicize-species: false", y),
             file.path(p, "_quarto.yml"))
  f <- in_project(p, .build_main_text("journal-of-ecology", "default",
                                      blinded = TRUE))
  y <- rmarkdown::yaml_front_matter(f)
  expect_identical(y$title, "Ants")
  expect_null(y$author)
  body <- readLines(f, warn = FALSE)
  expect_false(any(grepl("Correspondence", body)))
  # The identifying sections left for the title page.
  expect_false(any(trimws(body) == "# Acknowledgements"))
  expect_true(any(trimws(body) == "# Introduction"))
  # The package's settings are not pandoc's business.
  expect_null(y$easypaper)
  # Written on the package's Word template, with the journal resolved.
  expect_identical(y$format$docx$`reference-doc`,
                   system.file("word", "word_plain_paper_style.docx",
                               package = "easypaper"))
  expect_true(file.exists(y$csl))
})

test_that("a render never merges the manuscript with its supplement", {
  # Merging means handing both documents to pandoc, which rebuilds them and
  # loses every column width. One document per section, always.
  for (fn in list(.render, render_docx, render_pdf)) {
    expect_no_match(code_of(fn), ".merge_documents", fixed = TRUE)
  }
  expect_false("split" %in% names(formals(render_docx)))
  expect_false("split" %in% names(formals(render_pdf)))
})

test_that("the deliverable builders render the supplement exactly once", {
  # make_submission() and make_preprint() render it themselves, with their own
  # subset of files and their own labelled names. Without supplement = FALSE
  # they would get a second, unlabelled copy from .render().
  count <- function(fn, pat) {
    length(regmatches(code_of(fn), gregexpr(pat, code_of(fn), fixed = TRUE))[[1]])
  }
  for (fn in list(make_submission, make_preprint)) {
    expect_identical(count(fn, "supplement = FALSE"), 1L)
    expect_identical(count(fn, "render_supplementary("), 1L)
  }
})

test_that("a flextable keeps its natural width and is never stretched", {
  # Quarto wraps every captioned table in a container 5.5 inches wide, and the
  # helper used to force the table to exactly 6. autofit() alone is the width
  # that works; this only brings back a table too wide for the page.
  e <- new.env()
  for (x in as.list(parse(tpl("R/setup.R"), keep.source = FALSE))) {
    if (is.call(x) && identical(as.character(x[[1]]), "<-") &&
        identical(as.character(x[[2]]), "fit_flextable_to_page")) {
      eval(x, envir = e)
    }
  }
  expect_true(is.function(e$fit_flextable_to_page))
  expect_identical(formals(e$fit_flextable_to_page)$pgwidth, 5.5)

  narrow <- flextable::flextable(data.frame(a = 1:2, b = c("x", "y")))
  expect_equal(dim(e$fit_flextable_to_page(narrow))$widths,
               dim(flextable::autofit(narrow))$widths)
  wide <- flextable::flextable(
    as.data.frame(matrix(strrep("long text here ", 3), 2, 8)))
  expect_gt(sum(dim(flextable::autofit(wide))$widths), 5.5)
  expect_equal(sum(dim(e$fit_flextable_to_page(wide))$widths), 5.5)
})

test_that("the Word templates draw no rule around a table", {
  # Quarto wraps every captioned float in a container table, and the template's
  # `Table` style used to give it a thick rule above and below.
  docs <- list.files(system.file("word", package = "easypaper"), "[.]docx$",
                     full.names = TRUE)
  expect_length(docs, 3L)
  for (f in docs) {
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
  # columns measured from their content.
  qmd <- list.files(tpl("_sections"), "[.]qmd$", full.names = TRUE)
  for (f in c(qmd, tpl("manuscript.qmd"), tpl("supplementary.qmd"))) {
    txt <- readLines(f, warn = FALSE)
    code <- txt[!grepl("^\\s*#", txt)]
    expect_false(any(grepl("kable(", code, fixed = TRUE)), info = basename(f))
  }
})

test_that("no render carries a date", {
  y <- rmarkdown::yaml_front_matter(tpl("manuscript.qmd"))
  expect_null(y$date)
  expect_null(y[["date-format"]])
})

test_that("the supplement names its authors, and a blinded one names nobody", {
  expect_identical(formals(render_supplementary)$blind, FALSE)
  expect_identical(formals(.build_supplementary)$blinded, FALSE)
  # make_submission() passes its own blinding through to the supplement.
  expect_match(code_of(make_submission), "blind = blind)", fixed = TRUE)
  expect_match(code_of(render_supplementary),
               ".manuscript_reference(journal, blinded = blind)", fixed = TRUE)
  expect_match(code_of(render_supplementary), "list(subtitle = reference)",
               fixed = TRUE)

  p <- new_project(title = "Ants", authors = c("Ada Lovelace", "Alan Turing"))
  in_project(p, {
    expect_identical(.manuscript_reference("journal-of-ecology"),
                     "Lovelace, A., Turing, A. Ants. Journal of Ecology.")
    expect_identical(.manuscript_reference("journal-of-ecology", blinded = TRUE),
                     "Ants. Journal of Ecology.")
  })
})

test_that("the title page is built from the manuscript, with no file of its own", {
  # It used to be title_page.qmd, with the title and the headings of the
  # blinded sections written a second time. Now everything on it comes from
  # manuscript.qmd and the blinded-sections: list, in that order.
  expect_false(file.exists(tpl("title_page.qmd")))
  ms <- readLines(tpl("manuscript.qmd"), warn = FALSE)
  expect_length(BLINDED_SECTIONS, 4L)
  for (h in BLINDED_SECTIONS) {
    expect_true(any(trimws(ms) == paste("#", h)), info = h)
  }
  p <- new_project(title = "Ants")
  expect_false(file.exists(file.path(p, "title_page.qmd")))
  page <- readLines(in_project(p, .build_title_page()))
  # The headings of the page, not the comments of its chunks.
  heads <- function(page) {
    h <- trimws(page)
    h[h %in% paste("#", BLINDED_SECTIONS)]
  }
  expect_identical(heads(page), paste("#", BLINDED_SECTIONS))
  # Their order is the list's.
  y <- readLines(file.path(p, "_quarto.yml"))
  i <- grep("^    - Acknowledgements$", y)
  y <- y[-i]
  y <- append(y, "    - Acknowledgements", after = i + 2L)
  writeLines(y, file.path(p, "_quarto.yml"))
  page <- readLines(in_project(p, .build_title_page()))
  expect_false(identical(in_project(p, .blinded_sections()), BLINDED_SECTIONS))
  expect_identical(heads(page), paste("#", in_project(p, .blinded_sections())))

  # A title_page.qmd of the project's own is the page: what it adds stays,
  # and a section it has no heading for still comes, at the end.
  writeLines(c("Running head: Ants", "", "<!-- affiliations -->", "",
               "# Acknowledgements"), file.path(p, "title_page.qmd"))
  page <- readLines(in_project(p, .build_title_page()))
  expect_lt(which(page == "Running head: Ants"),
            which(page == "easypaper::affiliations()"))
  expect_setequal(heads(page), paste("#", BLINDED_SECTIONS))
})

test_that("a blinded submission moves the identifying sections, and only those", {
  l <- c("# One", "text one", "", "# Two", "text two", "", "# Three", "t3")
  expect_identical(.section_block(l, "Two"), c("# Two", "text two"))
  expect_identical(.section_block(l, "Nowhere"), character(0))
  expect_identical(.drop_sections(l, "Two"),
                   c("# One", "text one", "", "# Three", "t3"))
  expect_identical(BLINDED_SECTIONS[4], "Data availability statement")
  expect_match(code_of(.build_main_text), ".drop_sections(txt, .blinded_sections())",
               fixed = TRUE)
  expect_match(code_of(make_submission), "tp <- .build_title_page(journal)",
               fixed = TRUE)

  # The text written in the manuscript lands on the title page, under the
  # page's own heading, and the page carries the manuscript's title.
  p <- new_project(title = "Ants")
  ms <- readLines(file.path(p, "manuscript.qmd"))
  i <- which(ms == "# Acknowledgements")
  writeLines(append(ms, c("", "We thank the ants."), after = i),
             file.path(p, "manuscript.qmd"))
  f <- in_project(p, .build_title_page())
  page <- readLines(f)
  expect_identical(rmarkdown::yaml_front_matter(f)$title, "Ants")
  expect_true(any(page == "We thank the ants."))
  expect_identical(sum(trimws(page) == "# Acknowledgements"), 1L)

  # A project draws the line elsewhere in its _quarto.yml.
  y <- readLines(file.path(p, "_quarto.yml"))
  y <- y[!grepl("^    - (CRediT|Conflict|Data availability)", y)]
  writeLines(y, file.path(p, "_quarto.yml"))
  expect_identical(in_project(p, .blinded_sections()), "Acknowledgements")
})

test_that("the section files are numbered in the order the paper reads", {
  # Two digits, so the folder lists them as the manuscript includes them.
  ms  <- readLines(tpl("manuscript.qmd"), warn = FALSE)
  inc <- sub("^\\{\\{< include _sections/(.*) >\\}\\}$", "\\1",
             grep("^\\{\\{< include _sections/", ms, value = TRUE))
  files <- list.files(tpl("_sections"), "[.]qmd$")
  expect_setequal(inc, files)
  expect_identical(sort(files, method = "radix"), inc)
  expect_identical(inc[.section_order(inc)], inc)
  expect_true(all(grepl("^[0-9]{2}(\\.[0-9]+)?_", files)))

  # Sorted as numbers, 02 or 2 alike, and a part after its whole.
  f <- c("12.2_suppl_methods.qmd", "12_suppl_material.qmd", "2_intro.qmd",
         "12.1_suppl_figures.qmd", "10_figures.qmd", "notes.qmd", "01_abstract.qmd")
  expect_identical(f[.section_order(f)],
                   c("01_abstract.qmd", "2_intro.qmd", "10_figures.qmd",
                     "12_suppl_material.qmd", "12.1_suppl_figures.qmd",
                     "12.2_suppl_methods.qmd", "notes.qmd"))

  # The supplement and the figures are found by name, so a project numbered
  # its own way -- 8_suppl_material.qmd, 6_figures.qmd -- works too.
  is_suppl <- function(x) grepl(SUPPL_FILE, x)
  expect_true(all(is_suppl(c("12_suppl_material.qmd", "8_suppl_material.qmd",
                             "12.2_suppl_methods.qmd", "8_appendix_suppl.qmd",
                             "12_supplementary.qmd"))))
  expect_false(any(is_suppl(c("03_supplied.qmd", "suppl_notes.qmd",
                              "10_figures.qmd"))))
  expect_identical(.suppl_name("12.2_suppl_methods.qmd"), "methods")
  expect_identical(.suppl_name("8_suppl_material.qmd"), "material")
  expect_identical(.suppl_include_lines(c("{{< include _sections/12_suppl_material.qmd >}}",
                                          "{{< include _sections/10_figures.qmd >}}",
                                          "{{< include _sections/8_suppl_material.qmd >}}")),
                   c(1L, 3L))

  p <- new_project()
  expect_identical(basename(in_project(p, .suppl_files())), "12.1_suppl_material.qmd")
  expect_identical(basename(in_project(p, .figures_file())), "10_figures.qmd")
  file.rename(file.path(p, "_sections", c("10_figures.qmd", "12.1_suppl_material.qmd")),
              file.path(p, "_sections", c("6_figures.qmd", "8_suppl_material.qmd")))
  expect_identical(basename(in_project(p, .suppl_files())), "8_suppl_material.qmd")
  expect_identical(basename(in_project(p, .figures_file())), "6_figures.qmd")
  unlink(file.path(p, "_sections", "6_figures.qmd"))
  expect_null(in_project(p, .figures_file()))
})

test_that("the statements at the end have a file each, and travel with it", {
  ms <- readLines(tpl("manuscript.qmd"), warn = FALSE)
  files <- c(Acknowledgements = "06_acknowledgements.qmd",
             "CRediT authorship contribution statement" = "07_credit_statement.qmd",
             "Conflict of Interest Statement" = "08_conflict_of_interest.qmd",
             "Data availability statement" = "09_data_availability.qmd")
  expect_setequal(names(files), BLINDED_SECTIONS)
  for (h in names(files)) {
    inc <- sprintf("{{< include _sections/%s >}}", files[[h]])
    expect_identical(.section_block(ms, h), c(paste("#", h), "", inc), info = h)
    expect_true(file.exists(tpl("_sections", files[[h]])), info = h)
  }

  p <- new_project(title = "Ants")
  writeLines("We thank the ants.",
             file.path(p, "_sections", "06_acknowledgements.qmd"))
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(sub("italicize-species: true", "italicize-species: false", y),
             file.path(p, "_quarto.yml"))
  # Blinded: gone from the main text, the include and its text alike, and on
  # the title page instead, under its heading.
  main <- readLines(in_project(p, .build_main_text("journal-of-ecology",
                                                   "default", blinded = TRUE)))
  expect_false(any(grepl("We thank the ants|06_acknowledgements|07_credit_statement",
                         main)))
  page <- readLines(in_project(p, .build_title_page()))
  for (h in names(files)) {
    inc <- sprintf("{{< include _sections/%s >}}", files[[h]])
    expect_gt(which(page == inc), which(trimws(page) == paste("#", h)))
  }
  # Signed: in the main text, where the include is resolved, and off the page.
  main <- readLines(in_project(p, .build_main_text("journal-of-ecology",
                                                   "default")))
  expect_true(any(main == "We thank the ants."))
})

test_that("line numbers and line spacing are set on the submission's .docx", {
  # Defaults are what the Word templates already carry: numbered and double
  # spaced for the main text and the title page, 1.5 for the supplement.
  f <- formals(make_submission)
  expect_identical(f$line_numbers, TRUE)
  expect_identical(f$line_spacing, 2)
  expect_identical(f$suppl_line_spacing, 1.5)
  code <- code_of(make_submission)
  expect_match(code, ".docx_layout(main_file, line_numbers, line_spacing)", fixed = TRUE)
  expect_match(code, ".docx_layout(title_file, line_numbers, line_spacing)", fixed = TRUE)
  expect_match(code, "line_spacing = suppl_line_spacing)", fixed = TRUE)
  expect_error(.check_spacing(3, "line_spacing"), "1, 1.5 or 2")
  expect_error(.check_spacing("2", "line_spacing"), "1, 1.5 or 2")
  expect_silent(.check_spacing(1.5, "line_spacing"))

  part <- function(f, p) {
    d <- tempfile()
    utils::unzip(f, p, exdir = d)
    x <- file.path(d, p)
    readChar(x, file.size(x), useBytes = TRUE)
  }
  spacing <- function(f) {
    st <- part(f, "word/styles.xml")
    d <- regmatches(st, regexpr("<w:pPrDefault>.*?</w:pPrDefault>", st, perl = TRUE))
    as.integer(sub('.*w:line="([0-9]+)".*', "\\1", d))
  }
  numbered <- function(f) grepl("<w:lnNumType", part(f, "word/document.xml"), fixed = TRUE)
  copy <- function(name) {
    f <- tempfile(fileext = ".docx")
    file.copy(system.file("word", paste0(name, ".docx"), package = "easypaper"), f)
    f
  }
  main <- copy("word_plain_paper_style")
  expect_identical(spacing(main), 480L)
  expect_true(numbered(main))
  .docx_layout(main, line_numbers = FALSE, line_spacing = 1)
  expect_identical(spacing(main), 240L)
  expect_false(numbered(main))
  .docx_layout(main, line_numbers = TRUE, line_spacing = 1.5)
  expect_identical(spacing(main), 360L)
  expect_true(numbered(main))
  # Where the schema wants it, after the margins; once per section.
  doc <- part(main, "word/document.xml")
  expect_match(doc, '<w:pgMar [^>]*/><w:lnNumType w:countBy="1" w:restart="continuous"/>')
  expect_identical(lengths(regmatches(doc, gregexpr("<w:lnNumType", doc))), 1L)
  # NULL leaves the file alone, and it stays a .docx: [Content_Types].xml first.
  before <- unname(tools::md5sum(main))
  expect_false(.docx_layout(main))
  expect_identical(unname(tools::md5sum(main)), before)
  expect_identical(zip::zip_list(main)$filename[1], "[Content_Types].xml")

  sup <- copy("word_plain_paper_style_supplementary_material")
  expect_identical(spacing(sup), 360L)
  expect_false(numbered(sup))
  .docx_layout(sup, line_spacing = 2)
  expect_identical(spacing(sup), 480L)
  expect_false(numbered(sup))
  if (rmarkdown::pandoc_available()) {
    txt <- system2(rmarkdown::pandoc_exec(), c(shQuote(sup), "-t", "plain"),
                   stdout = TRUE)
    expect_true(length(txt) > 0)
  }

  # A template with no default spacing gets one.
  expect_match(.default_spacing("<w:docDefaults><w:rPrDefault/></w:docDefaults>", 480L),
               '<w:pPrDefault><w:pPr><w:spacing w:line="480" w:lineRule="auto"/></w:pPr></w:pPrDefault>',
               fixed = TRUE)
  expect_match(.default_spacing(paste0("<w:docDefaults><w:pPrDefault>\n<w:pPr><w:jc w:val=\"both\"/>",
                                       "</w:pPr></w:pPrDefault></w:docDefaults>"), 360L),
               '<w:pPr><w:spacing w:line="360" w:lineRule="auto"/><w:jc', fixed = TRUE)
  # An exact rule would read the height as points: it goes too.
  expect_match(.default_spacing(paste0('<w:docDefaults><w:pPrDefault><w:pPr><w:spacing ',
                                       'w:after="0" w:line="300" w:lineRule="exact"/>',
                                       '</w:pPr></w:pPrDefault></w:docDefaults>'), 240L),
               '<w:spacing w:line="240" w:lineRule="auto" w:after="0"/>', fixed = TRUE)
})

test_that("make_preprint() sets the line numbers and spacing of its PDFs", {
  # Numbered by default, as a submission is, and at the linestretch of
  # _quarto.yml, which is where that value is written.
  f <- formals(make_preprint)
  expect_identical(f$line_numbers, TRUE)
  expect_null(f$line_spacing)
  expect_null(f$suppl_line_spacing)
  expect_match(code_of(make_preprint), ".set_layout(", fixed = TRUE)

  b <- list(documentclass = "article", linestretch = 1.5)
  expect_identical(.pdf_layout(b, NULL), b)
  expect_identical(.pdf_layout(b, list(line_numbers = FALSE)), b)
  l <- .pdf_layout(b, list(line_numbers = TRUE, line_spacing = 2))
  expect_identical(l$linestretch, 2)
  expect_identical(l[["include-in-header"]],
                   list(list(text = "\\usepackage{lineno}\n\\linenumbers")))
  # Added to a header the project already has, of any shape.
  own <- .pdf_layout(c(b, list(`include-in-header` = "preamble.tex")),
                     list(line_numbers = TRUE))
  expect_identical(own[["include-in-header"]][[1]], "preamble.tex")
  expect_length(own[["include-in-header"]], 2L)
  own <- .pdf_layout(c(b, list(`include-in-header` = list(text = "\\usepackage{x}"))),
                     list(line_numbers = TRUE))
  expect_length(own[["include-in-header"]], 2L)

  # It reaches the manuscript and the supplement while make_preprint() runs,
  # and nothing else.
  p <- new_project()
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(sub("italicize-species: true", "italicize-species: false", y),
             file.path(p, "_quarto.yml"))
  built <- function() {
    .set_layout(main = list(line_numbers = TRUE, line_spacing = 2),
                suppl = list(line_spacing = 1))
    list(main = rmarkdown::yaml_front_matter(
           .build_main_text("journal-of-ecology", "default", "pdf")),
         suppl = rmarkdown::yaml_front_matter(
           .build_supplementary(.suppl_files()[1], 1L, 1L, fmt = "pdf")))
  }
  y <- in_project(p, built())
  expect_equal(y$main$format$pdf$linestretch, 2)
  hdr <- function(f) unlist(f$format$pdf[["include-in-header"]])
  expect_true(any(grepl("lineno", hdr(y$main), fixed = TRUE)))
  expect_equal(y$suppl$format$pdf$linestretch, 1)
  # The supplement's lines are never numbered; its captions follow the style.
  expect_false(any(grepl("lineno", hdr(y$suppl), fixed = TRUE)))
  expect_true(any(grepl("captionsetup", hdr(y$suppl), fixed = TRUE)))
  # Afterwards, a plain render is as _quarto.yml says.
  expect_null(.ep$layout)
  m <- rmarkdown::yaml_front_matter(
    in_project(p, .build_main_text("journal-of-ecology", "default", "pdf")))
  expect_identical(m$format$pdf$linestretch, 1.5)
  expect_false(any(grepl("lineno", hdr(m), fixed = TRUE)))
})

test_that("only a double-blind submission has a title page", {
  # Signed, the main text already opens with the title, the authors and their
  # affiliations and carries the statements at the end: a title page would
  # only repeat it. One left by an earlier blinded call goes.
  code <- code_of(make_submission)
  expect_match(code, "if (blind) { own <-", fixed = TRUE)
  expect_match(code, "else if (file.exists(title_file)) { unlink(title_file)",
               fixed = TRUE)
  # And the checklist speaks of the page only when there is one.
  f <- tempfile(fileext = ".md")
  .write_checklist(f, "Oryx", "Oryx", blinded = TRUE)
  expect_true(any(grepl("Title page:", readLines(f), fixed = TRUE)))
  expect_true(any(grepl("Double blind", readLines(f), fixed = TRUE)))
  .write_checklist(f, "Oryx", "Oryx", blinded = FALSE)
  expect_false(any(grepl("Title page|Double blind", readLines(f))))
  expect_true(any(grepl("Front page of `main_*.docx`", readLines(f),
                        fixed = TRUE)))
})

test_that("the title is written once, in manuscript.qmd", {
  # The title page has no front matter at all, and Quarto is not asked to
  # render it on its own.
  expect_false(file.exists(tpl("title_page.qmd")))
  expect_false("title_page.qmd" %in%
                 unlist(yaml::read_yaml(tpl("_quarto.yml"))$project$render))
  p <- new_project(title = "Ants")
  f <- in_project(p, .build_title_page())
  expect_identical(rmarkdown::yaml_front_matter(f)$title, "Ants")
  # A title of its own is overwritten: the manuscript's is the one.
  writeLines(c("---", 'title: "Old"', "---", "", "<!-- affiliations -->"),
             file.path(p, "title_page.qmd"))
  f <- in_project(p, .build_title_page())
  expect_identical(rmarkdown::yaml_front_matter(f)$title, "Ants")
  expect_false(any(readLines(f) == 'title: "Old"'))

  # check_title() warns while it is the template's, and every render runs it.
  expect_true(check_title(quiet = TRUE, path = p))
  q <- new_project()
  expect_warning(expect_false(check_title(quiet = TRUE, path = q)),
                 "template's title")
  expect_match(code_of(.render), "check_title(quiet = TRUE)", fixed = TRUE)

  # The README's heading follows the title while it is still the template's.
  readme <- file.path(q, "README.md")
  expect_true(.sync_readme_title(readme, "Ants"))
  expect_identical(readLines(readme, n = 1L), "# Ants")
  expect_false(.sync_readme_title(readme, "Bees"))
  expect_identical(readLines(readme, n = 1L), "# Ants")
})

test_that("a short title is printed under the title, and only when there is one", {
  expect_null(.short_title(list(title = "x")))
  expect_null(.short_title(list(`short-title` = "  ")))
  expect_identical(.short_title(list(`short-title` = " Ants ")), "Ants")
  expect_identical(.with_short_title(list(title = "T"), list()), list(title = "T"))
  # A second line of the title, after a hard line break, so it is set in the
  # title's own font and size; the plain title still names the document.
  y <- .with_short_title(list(title = "T", `short-title` = "S"),
                         list(`short-title` = "S"))
  expect_identical(y$title, "T\\\nShort title: S")
  expect_identical(y$pagetitle, "T")
  expect_identical(y[["title-meta"]], "T")
  expect_null(y$subtitle)
  expect_null(y[["short-title"]])
  # A subtitle of the manuscript's own stays where it was.
  y <- .with_short_title(list(title = "T", subtitle = "A study"),
                         list(`short-title` = "S"))
  expect_identical(y$subtitle, "A study")
  expect_identical(y$title, "T\\\nShort title: S")
  # The template carries it commented out: nothing is printed until written.
  ms <- readLines(tpl("manuscript.qmd"), warn = FALSE)
  expect_true(any(grepl("^# short-title: ", ms)))
  expect_null(rmarkdown::yaml_front_matter(tpl("manuscript.qmd"))[["short-title"]])

  p <- new_project(title = "Chemical mimicry in ants")
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(sub("italicize-species: true", "italicize-species: false", y),
             file.path(p, "_quarto.yml"))
  title_of <- function(f) rmarkdown::yaml_front_matter(f)$title
  in_project(p, {
    expect_identical(title_of(.build_main_text("journal-of-ecology", "default")),
                     "Chemical mimicry in ants")
    expect_identical(title_of(.build_title_page()), "Chemical mimicry in ants")
  })
  ms <- readLines(file.path(p, "manuscript.qmd"))
  writeLines(sub("^# short-title: .*$", 'short-title: "Mimicry in ants"', ms),
             file.path(p, "manuscript.qmd"))
  in_project(p, {
    for (f in list(.build_main_text("journal-of-ecology", "default"),
                   .build_main_text("journal-of-ecology", "default", blinded = TRUE),
                   .build_main_text("journal-of-ecology", "default", "html",
                                    whole = TRUE),
                   .build_title_page())) {
      expect_identical(title_of(f),
                       "Chemical mimicry in ants\\\nShort title: Mimicry in ants")
      expect_null(rmarkdown::yaml_front_matter(f)$subtitle)
      expect_null(rmarkdown::yaml_front_matter(f)[["short-title"]])
    }
    # A preprint prints none: a running head is a journal's business.
    f <- .build_main_text("journal-of-ecology", "default", "pdf",
                          short_title = FALSE)
    expect_identical(title_of(f), "Chemical mimicry in ants")
    expect_null(rmarkdown::yaml_front_matter(f)[["short-title"]])
  })
  expect_match(code_of(make_preprint), "short_title = FALSE)", fixed = TRUE)
  expect_no_match(code_of(make_submission), "short_title", fixed = TRUE)
})

test_that("pandoc reads the short title as a second line of the title", {
  skip_if_not(rmarkdown::pandoc_available())
  y <- .with_short_title(list(title = "Ants *Formica*"),
                         list(`short-title` = "Ants"))
  f <- tempfile(fileext = ".md")
  writeLines(c("---", .as_yaml(y), "---", "", "Text."), f)
  out <- system2(rmarkdown::pandoc_exec(), c(shQuote(f), "-s", "-t", "html"),
                 stdout = TRUE)
  expect_true(any(grepl("Ants <em>Formica</em><br />", out, fixed = TRUE)))
  expect_true(any(grepl("Short title: Ants</h1>", out, fixed = TRUE)))
  expect_true(any(grepl("<title>Ants Formica</title>", out, fixed = TRUE)))
})

test_that("the title page loses any Word template it names, and is never empty", {
  # A title_page.qmd that names a Word template of its own would beat the one
  # the render passes: a document's own format wins over metadata.
  p <- new_project()
  writeLines(c("---", "format:", "  docx:",
               "    reference-doc: format/word_plain_paper_style.docx", "---",
               "", "<!-- affiliations -->"), file.path(p, "title_page.qmd"))
  f <- in_project(p, .build_title_page())
  y <- rmarkdown::yaml_front_matter(f)
  # Quarto refuses `docx:` with nothing under it.
  expect_identical(y$format$docx, "default")
})

test_that("render_pdf() names its file the way render_docx() does", {
  # manuscript_<journal>, so a render for another journal does not overwrite
  # it; preprint_<label>.pdf is make_preprint()'s.
  expect_match(code_of(render_docx), 'paste0("manuscript_", journal, ".docx")',
               fixed = TRUE)
  expect_match(code_of(render_pdf), 'paste0("manuscript_", journal, ".pdf")',
               fixed = TRUE)
  expect_no_match(code_of(render_pdf), "preprint", fixed = TRUE)
})

test_that("the keywords are written under the abstract, once", {
  # Not in the YAML: Quarto prints the `keywords:` of the YAML in the head of
  # an .html, and the manuscript printed them again.
  expect_null(rmarkdown::yaml_front_matter(tpl("manuscript.qmd"))$keywords)
  ms <- readLines(tpl("manuscript.qmd"), warn = FALSE)
  expect_false(any(trimws(ms) == "# Keywords"))
  expect_false(any(grepl("$keywords", ms, fixed = TRUE)))
  ab <- readLines(tpl("_sections", "01_abstract.qmd"), warn = FALSE)
  expect_identical(utils::tail(ab, 1), "**Keywords:** keyword1, keyword2, keyword3")

  # The deposit's metadata reads them from there.
  p <- new_project()
  expect_identical(in_project(p, .keywords()), c("keyword1", "keyword2", "keyword3"))
  f <- file.path(p, "_sections", "01_abstract.qmd")
  writeLines(c("Text.", "", "<!-- Keywords: not these -->",
               "*Key words*: *Formica rufa*; mimicry, ants."), f)
  expect_identical(in_project(p, .keywords()), c("Formica rufa", "mimicry", "ants"))
  # Without the line, Quarto's own `keywords:` of the YAML.
  writeLines("Text.", f)
  ms <- readLines(file.path(p, "manuscript.qmd"))
  writeLines(append(ms, "keywords: [old, ones]", after = 1L),
             file.path(p, "manuscript.qmd"))
  expect_identical(in_project(p, .keywords()), c("old", "ones"))
})

test_that("the title page carries no leftover empty fields", {
  p <- new_project()
  tp <- paste(readLines(in_project(p, .build_title_page())), collapse = "\n")
  for (f in c("Running head", "Word count", "Supplementary items",
              "ORCID", "Funding", "Keywords")) {
    expect_no_match(tp, f, fixed = TRUE, info = f)
  }
})

test_that("the placeholders say what to replace, and the code knows them", {
  y <- rmarkdown::yaml_front_matter(tpl("manuscript.qmd"))
  expect_identical(y$title, "Manuscript title here")
  expect_identical(vapply(y$author, function(a) a$name, character(1)),
                   c("Author1", "Author2"))
  expect_identical(TEMPLATE_TITLE, y$title)
  expect_identical(readLines(tpl("README.md"), n = 1L), paste("#", TEMPLATE_TITLE))

  # Every render warns while they are still there, so the list has to match:
  # the names with their affiliation marks stripped.
  p <- new_project()
  expect_identical(in_project(p, .author_names()), TEMPLATE_AUTHORS)
  expect_warning(in_project(p, .check_license()), "template authors")
})

test_that("the journal is named in full, from its own style file", {
  p <- new_project()
  in_project(p, {
    expect_identical(.journal_name("journal-of-ecology"), "Journal of Ecology")
    expect_identical(.journal_name("no-such-style"), "no-such-style")
  })
})

test_that("a name is written the way a reference writes it", {
  expect_identical(.reference_name("Ada Lovelace"), "Lovelace, A.")
  expect_identical(.reference_name("Daniel Sanchez-Garcia"), "Sanchez-Garcia, D.")
  expect_identical(.reference_name("Ada Byron Lovelace"), "Lovelace, A. B.")
  expect_identical(.reference_name("Prince"), "Prince")
})

test_that("the supplement carries no address", {
  sup <- paste(readLines(tpl("supplementary.qmd"), warn = FALSE), collapse = "\n")
  expect_no_match(sup, "affiliations", fixed = TRUE)
  expect_no_match(sup, "Correspondence", fixed = TRUE)
})

test_that("the affiliations are written in the YAML of manuscript.qmd", {
  # Not a file of _sections/, which holds the text, and no number written by
  # hand: a chunk right under the YAML prints them.
  ms <- readLines(tpl("manuscript.qmd"), warn = FALSE)
  a  <- .affiliation_lines(ms)
  expect_true(any(grepl("easypaper::affiliations()", ms[a], fixed = TRUE)))
  expect_identical(ms[min(a)], "```{r affiliations}")
  # Right under the YAML, before the first heading: they open the document.
  yaml_end <- grep("^---\\s*$", ms)[2]
  expect_gt(min(a), yaml_end)
  expect_lt(max(a), which(ms == "# Abstract"))
  y <- rmarkdown::yaml_front_matter(tpl("manuscript.qmd"))
  expect_identical(.title_block(y)$line, "Author1^1,\\*^, Author2^2^")
  expect_length(.title_block(y)$lines, 3L)
})

test_that("the affiliations chunk is found however it is written", {
  # No chunk is a paper with no affiliations.
  expect_identical(.affiliation_lines(c("---", "title: x", "---", "",
                                        "# Abstract")), integer(0))
  # The chunk, however it is written, or inline.
  ch <- c("---", "title: x", "---", "", "```{r}", "#| include: true",
          "affiliations()", "```", "", "```{r setup}", "x <- 1", "```")
  expect_identical(.affiliation_lines(ch), 5:8)
  expect_identical(.affiliation_lines(c(ch, "`r easypaper::affiliations()`")),
                   c(5:8, 13L))
  expect_identical(.affiliation_lines(c("x", "```{r}", "affiliations()")), 2:3)
  # A comment that names it is not a call.
  expect_identical(.affiliation_lines(c("```{r}", "# affiliations() below",
                                        "```")), integer(0))
})

test_that("the title page is given the manuscript's affiliations", {
  p <- new_project(title = "Ants")
  page <- readLines(in_project(p, .build_title_page()))
  expect_identical(sum(page == "easypaper::affiliations()"), 1L)
  expect_false(any(grepl(AFFILIATIONS_SLOT, page)))
  # Under the title, above the sections the page carries.
  expect_lt(which(page == "easypaper::affiliations()"),
            which(trimws(page) == "# Acknowledgements"))
  # A blinded main text carries none of it, in the body or in the YAML.
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(sub("italicize-species: true", "italicize-species: false", y),
             file.path(p, "_quarto.yml"))
  f <- in_project(p, .build_main_text("journal-of-ecology", "default",
                                      blinded = TRUE))
  expect_false(any(grepl("affiliations(", readLines(f), fixed = TRUE)))
  expect_null(rmarkdown::yaml_front_matter(f)$affiliations)
  expect_null(rmarkdown::yaml_front_matter(f)$author)

  # A title_page.qmd of the project's own takes them where it marks them.
  writeLines(c("---", "---", "", "Running head: Ants", "",
               "<!-- affiliations -->", "", "# Acknowledgements"),
             file.path(p, "title_page.qmd"))
  page <- readLines(in_project(p, .build_title_page()))
  expect_identical(sum(page == "easypaper::affiliations()"), 1L)
  expect_false(any(grepl(AFFILIATIONS_SLOT, page)))
  expect_lt(which(page == "Running head: Ants"),
            which(page == "easypaper::affiliations()"))
})

test_that("every .docx is repaired before it is handed over", {
  # Quarto wraps each captioned float in a one-cell table and puts the
  # flextable inside it, so the cell ends with a table. The schema requires a
  # paragraph there, and Word refuses the file.
  count <- function(fn) {
    length(regmatches(code_of(fn), gregexpr(".repair_docx(", code_of(fn),
                                            fixed = TRUE))[[1]])
  }
  # The manuscript, whole or as the main text alone, the supplement, and the
  # title page.
  expect_identical(count(.render), 1L)
  expect_identical(count(render_supplementary), 1L)
  expect_identical(count(make_submission), 1L)

  xml <- paste("<w:sectPr>", "<w:pgSz w:h=\"15840\" w:w=\"12240\" />",
               "<w:pgMar w:bottom=\"1440\" w:left=\"1440\" w:right=\"1440\" />",
               "</w:sectPr>", sep = "\n")
  expect_identical(.text_width(xml), 9360L)
  expect_true(is.na(.text_width("<w:body/>")))
})

test_that("a figure paragraph is not indented", {
  code <- code_of(body(.repair_docx))
  expect_match(code, 'w:ind w:firstLine=', fixed = TRUE)
  expect_match(code, "(<w:jc [^>]*/>)", fixed = TRUE)
})

test_that("the cover letter is addressed to the journal, not to the label", {
  code <- code_of(make_submission)
  expect_match(code, "jname <- .journal_name(journal)", fixed = TRUE)
  expect_match(code, 'sprintf("cover_letter_%s.docx", label)', fixed = TRUE)
  expect_match(code, "jname)", fixed = TRUE)
  expect_match(code_of(.write_cover_letter), '.word_template("letter")',
               fixed = TRUE)
})

test_that("the label is built from the journal unless you give one", {
  expect_identical(.label_from("Ecology Letters"), "EcologyLetters")
  expect_identical(.label_from("Journal of Ecology"), "JournalofEcology")
  expect_identical(.label_from("PLOS ONE (new)"), "PLOSONEnew")
  expect_identical(.label_from("///"), "submission")
  expect_null(formals(make_submission)$label)
  expect_match(code_of(make_submission), "label <- .label_from(jname)",
               fixed = TRUE)
})

test_that("the journal comes from the manuscript unless a call names one", {
  p <- new_project()
  in_project(p, {
    expect_identical(.resolve_journal("ecology-letters"), "ecology-letters")
    expect_identical(.resolve_journal(NULL), "journal-of-ecology")
  })
  # Every entry point defaults to NULL and resolves.
  for (fn in list(render_docx, render_pdf, render_html, render_supplementary,
                  render_all, make_submission, make_preprint)) {
    expect_null(formals(fn)$journal)
    expect_match(code_of(fn), "journal <- .resolve_journal(journal)",
                 fixed = TRUE)
  }
})

test_that("the supplement is rendered with the project's settings", {
  # The wrapper .build_supplementary() writes is not in the render: list of
  # _quarto.yml, so NOTHING in the project configuration reaches it. Left to
  # Quarto's defaults the supplement came out with the R code of every chunk
  # printed above its figure, and its figures at 96 dpi.
  p <- new_project()
  f <- in_project(p, .build_supplementary(
    file.path(p, "_sections/12.1_suppl_material.qmd"), k = 1L, n = 1L, fmt = "docx"))
  yml  <- rmarkdown::yaml_front_matter(f)
  proj <- yaml::read_yaml(file.path(p, "_quarto.yml"))
  expect_false(isTRUE(yml$execute$echo))
  expect_equal(yml$execute, proj$execute)
  expect_equal(yml$knitr, proj$knitr)
  expect_identical(yml$knitr$opts_chunk$fig.path, "figures/png/")
  # The supplement's own Word template, and the project's docx settings.
  expect_identical(yml$format$docx$`reference-doc`,
                   system.file("word", "word_plain_paper_style_supplementary_material.docx",
                               package = "easypaper"))
  expect_identical(yml$format$docx$toc, proj$format$docx$toc)
  # Asked for a .pdf, it gets the project's LaTeX settings, not Quarto's.
  f <- in_project(p, .build_supplementary(
    file.path(p, "_sections/12.1_suppl_material.qmd"), k = 1L, n = 1L, fmt = "pdf"))
  yml <- rmarkdown::yaml_front_matter(f)
  expect_identical(yml$format$pdf$documentclass, proj$format$pdf$documentclass)
  expect_null(yml$format$docx)
})

test_that("the supplement's section and setup are written once, in the manuscript", {
  # supplementary.qmd includes no section and loads no setup: the wrapper puts
  # in the section it renders and the manuscript's R/setup.R, so a second
  # supplement is an include in manuscript.qmd and nothing else.
  sup <- readLines(tpl("supplementary.qmd"), warn = FALSE)
  expect_length(.suppl_include_lines(sup), 0L)
  expect_false(any(grepl("^```\\{r", sup)))
  expect_false("supplementary.qmd" %in%
                 unlist(yaml::read_yaml(tpl("_quarto.yml"))$project$render))

  p <- new_project()
  file.copy(file.path(p, "_sections", "12.1_suppl_material.qmd"),
            file.path(p, "_sections", "12.2_suppl_methods.qmd"))
  for (k in 1:2) {
    sec <- in_project(p, .suppl_files())[k]
    f <- in_project(p, .build_supplementary(sec, k = k, n = 2L))
    body <- readLines(f)
    inc <- sprintf("{{< include _sections/%s >}}", basename(sec))
    expect_identical(sum(body == inc), 1L)
    expect_length(.suppl_include_lines(body), 1L)
    expect_identical(sum(body == 'source(here::here("R/setup.R"))'), 1L)
    # The section, the setup above it, the references below.
    expect_lt(which(body == 'source(here::here("R/setup.R"))'), which(body == inc))
    expect_lt(which(body == inc), which(trimws(body) == "# References"))
    expect_identical(rmarkdown::yaml_front_matter(f)$title, sprintf("Appendix S%d", k))
  }
  f <- in_project(p, .build_supplementary(in_project(p, .suppl_files())[1], 1L, 1L))
  expect_identical(rmarkdown::yaml_front_matter(f)$title, "Supporting Information")
})

test_that("the default caption style is the crossref: block of _quarto.yml", {
  # Written once, there, where preview() reads it too: a render used to
  # overwrite it with the package's own default.
  p <- new_project()
  in_project(p, {
    cr <- crossref_metadata("default")
    proj <- yaml::read_yaml(.p("_quarto.yml"))$crossref
    expect_identical(cr[["fig-title"]], proj[["fig-title"]])
    expect_identical(cr[["title-delim"]], proj[["title-delim"]])
  })
  y <- readLines(file.path(p, "_quarto.yml"))
  y <- sub('^  fig-title: "Figure"', '  fig-title: "Fig."', y)
  y <- sub('^  title-delim: "."', '  title-delim: ":"', y)
  y <- sub('reference-prefix: "Figure S"', 'reference-prefix: "Fig. S"', y)
  writeLines(y, file.path(p, "_quarto.yml"))
  in_project(p, {
    cr <- crossref_metadata("default")
    expect_identical(cr[["fig-title"]], "Fig.")
    expect_identical(cr[["fig-prefix"]], "Fig.")
    expect_identical(cr[["title-delim"]], ":")
    sfig <- Filter(function(k) identical(k$key, "sfig"), cr$custom)[[1]]
    expect_identical(sfig[["reference-prefix"]], "Fig. S")
    # Another style still wins for its call, and a style of the project's
    # own takes what it does not give from this default.
    expect_identical(crossref_metadata("abbrev")[["title-delim"]], ".")
  })
})

test_that("the deposit's metadata describes every data file, however many", {
  # dataspice 1.1.1 only builds its list of files when it is handed ONE path,
  # so two .csv files stopped every render with "object 'file_paths' not
  # found".
  p <- new_project(title = "A title", authors = "Ada Lovelace")
  d <- file.path(p, "data")
  write.csv(data.frame(a = 1, b = 2), file.path(d, "one.csv"), row.names = FALSE)
  write.csv(data.frame(x = 1, y = 2), file.path(d, "two.csv"), row.names = FALSE)
  write.csv(data.frame(k = 1), file.path(d, "three.csv"), row.names = FALSE)

  expect_no_error(sync_metadata(quiet = TRUE, path = p))
  attr <- read.csv(file.path(d, "metadata", "attributes.csv"))
  acc  <- read.csv(file.path(d, "metadata", "access.csv"))
  expect_setequal(unique(attr$fileName), c("one.csv", "two.csv", "three.csv"))
  expect_setequal(acc$fileName, c("one.csv", "two.csv", "three.csv"))
  expect_identical(nrow(attr), 5L)
  bib <- read.csv(file.path(d, "metadata", "biblio.csv"))
  expect_identical(bib$title, "A title")
  expect_true("Ada Lovelace" %in% read.csv(file.path(d, "metadata", "creators.csv"))$name)

  # A second render adds nothing and says nothing.
  expect_no_warning(sync_metadata(quiet = TRUE, path = p))
  expect_identical(nrow(read.csv(file.path(d, "metadata", "attributes.csv"))), 5L)

  # A file added later is picked up on its own.
  write.csv(data.frame(z = 1, w = 2), file.path(d, "four.csv"), row.names = FALSE)
  expect_no_warning(sync_metadata(quiet = TRUE, path = p))
  attr <- read.csv(file.path(d, "metadata", "attributes.csv"))
  expect_identical(nrow(attr), 7L)
  expect_true("four.csv" %in% attr$fileName)
})

test_that("a supplementary citation written by R code is resolved too", {
  n <- c("stbl-raw" = "Table S1", "sfig-map" = "Figure S1",
         "sfig-map-detail" = "Figure S2")
  expect_identical(
    .resolve_suppl_refs(c("see @stbl-raw; also [@sfig-map] and @sfig-map-detail.",
                          "ends in @stbl-raw.", "@stbl-rawer and x@stbl-raw stay"), n),
    c("see Table S1; also (Figure S1) and Figure S2.",
      "ends in Table S1.", "@stbl-rawer and x@stbl-raw stay"))

  ch <- .suppl_refs_chunk(n)
  expect_true(any(grepl("#| cache: false", ch, fixed = TRUE)))
  expect_no_error(parse(text = ch[!grepl("^```", ch)]))

  old <- knitr::knit_hooks$get()
  on.exit(knitr::knit_hooks$set(old), add = TRUE)
  src <- c(ch,
           "```{r}", "#| echo: false", "f <- function() 'see @stbl-raw'",
           "g <- function() '[@sfig-map]'", "```", "",
           "Values: `r f()`. Map `r g()`.")
  out <- paste(knitr::knit(text = src, quiet = TRUE, envir = new.env()),
               collapse = "\n")
  expect_match(out, "Values: see Table S1. Map (Figure S1).", fixed = TRUE)
  expect_no_match(out, "@stbl-raw", fixed = TRUE)
  expect_match(code_of(.build_main_text),
               "if (length(numbers)) .suppl_refs_chunk(numbers)", fixed = TRUE)
})

# A project reduced to what the checks read: a master that includes one
# section, and whatever else the test writes.
bare_project <- function(section) {
  d <- tempfile("bare")
  dir.create(file.path(d, "R"), recursive = TRUE)
  dir.create(file.path(d, "_sections"))
  writeLines("project:\n  type: default", file.path(d, "_quarto.yml"))
  writeLines(c("# master", "{{< include _sections/s.qmd >}}"),
             file.path(d, "manuscript.qmd"))
  writeLines(section, file.path(d, "_sections", "s.qmd"))
  d
}

test_that("a figure cited from R code counts as cited", {
  d <- bare_project(c(
    "```{r}", "#| label: fig-a", "#| include: true", "plot(1)", "```",
    "```{r}", "#| label: fig-b", "plot(2)", "```",
    "```{r}", "#| label: fig-c", "plot(3)", "```",
    "```{r}", "#| label: fig-d", "plot(4)", "```",
    "```{r}",
    "p <- sprintf('As shown in @fig-a, n = %d.', 3L)",
    "dyn <- sprintf('@fig-%s', 'b')        # built at run time: unreadable",
    "# a comment naming @fig-c is not a citation",
    "x <- methods::new('numeric')",
    "```",
    "`r p` And `r 'see @fig-ghost'`."))
  writeLines("f <- function() 'see @fig-d'", file.path(d, "R", "setup.R"))

  keys <- in_project(d, .code_keys(file.path(d, "_sections", "s.qmd")))
  expect_setequal(keys, c("fig-a", "fig-ghost", "fig-d"))
  # A comment is not a citation, in R/ either.
  writeLines("# cite it as @fig-c", file.path(d, "R", "analysis_notes.R"))

  msgs <- character(0)
  withCallingHandlers(expect_no_error(check_crossrefs(path = d)),
                      message = function(m) {
                        msgs <<- c(msgs, conditionMessage(m))
                        invokeRestart("muffleMessage")
                      })
  orphan <- grep("never cited", msgs, value = TRUE)
  expect_match(orphan, "fig-b, fig-c", fixed = TRUE)
  expect_no_match(orphan, "fig-a", fixed = TRUE)
  expect_no_match(orphan, "fig-d", fixed = TRUE)
  expect_true(any(grepl("cited from R code.*fig-ghost", msgs)))
})

test_that("a package the manuscript loads and nobody installed stops the render first", {
  d <- bare_project(c("```{r}", "#| label: setup", "library(noSuchPkgB)", "```"))
  writeLines(c("library(here)        # paths", "library(\"stats\")",
               "# library(commented.out.pkg)", "require(noSuchPkgA)",
               "x <- noSuchPkgC::f   # a :: may be guarded: not read"),
             file.path(d, "R", "setup.R"))
  err <- tryCatch(check_packages(d), error = conditionMessage)
  expect_match(err, "not installed: noSuchPkgA, noSuchPkgB.", fixed = TRUE)
  expect_match(err, 'install.packages(c("noSuchPkgA", "noSuchPkgB"))', fixed = TRUE)
  expect_no_match(err, "commented|noSuchPkgC|here|stats")
  # And it runs before anything else a render does.
  expect_match(code_of(.render), "check_packages() check_citations()",
               fixed = TRUE)
})

test_that("an e-mail address is not a citation, however it is written", {
  # An address in the affiliations stopped the render with "Citations with no
  # entry in references/*.bib: example.org" when the letter before the @ was
  # accented, or the @ was escaped -- which is what RStudio's visual editor
  # writes over the template's line on every save.
  f <- tempfile(fileext = ".qmd")
  writeLines(enc2utf8(c(
    "^\\*^ Correspondence: josé@example.org",
    "Also: garcía@example.org, m.pérez@example.org",
    "Or: correspondent\\@example.org, and plain ana@example.org",
    "\\^\\*\\^ Correspondence: correspondent\\@example.org",
    "But this cites [@smith2020] and @jones2021, and see @fig-map.")),
    f, useBytes = TRUE)
  expect_setequal(.at_keys(f), c("smith2020", "jones2021", "fig-map"))

  x <- enc2utf8(c("see @sfig-map.", "josé@sfig-map", "\\@sfig-map"))
  expect_identical(.resolve_suppl_refs(x, c("sfig-map" = "Figure S1")),
                   enc2utf8(c("see Figure S1.", "josé@sfig-map",
                              "\\@sfig-map")))
})

test_that("every render hands Quarto the references with their names in italics", {
  # By both roads a render takes: the manuscript, whole or as the main text
  # alone, through its copy; and the supplement.
  expect_match(code_of(render_supplementary), "bib <- .bibliography()", fixed = TRUE)
  expect_match(code_of(.build_main_text), "yml$bibliography <- .bibliography()",
               fixed = TRUE)
})

test_that(".bibliography() hands Quarto an italic copy, once per version of the file", {
  ok <- tryCatch({ .sp_find_pandoc(); TRUE }, error = function(e) FALSE)
  skip_if_not(ok, "pandoc is not available")
  p <- new_project()
  refs <- file.path(p, "references")
  writeLines(c("@article{perez2020,",
               "  title = {Effects of Fire on Pinus halepensis Regeneration},",
               "  author = {P{\\'e}rez, Juan}, journal = {Oryx}, year = {2020}}"),
             file.path(refs, "references.bib"))
  # Offline, from the answers the fixtures keep: nothing is looked up.
  file.copy(test_path("fixtures", "italicize_species", "cache.rds"),
            file.path(refs, "species_cache.rds"))
  old <- options(easypaper.species_offline = TRUE)
  on.exit(options(old), add = TRUE)
  rm(list = ls(.species_done), envir = .species_done)

  expect_message(bib <- in_project(p, .bibliography()), "Pinus halepensis")
  expect_length(bib, 2L)
  expect_identical(normalizePath(dirname(bib[[1]])), normalizePath(tempdir()))
  expect_match(jsonlite::read_json(bib[[1]])[[1]]$title,
               '<i><span class="nocase">Pinus halepensis</span></i>', fixed = TRUE)
  expect_setequal(list.files(refs),
                  c("references.bib", "packages.bib", "species_cache.rds",
                    "journal-of-ecology.csl"))
  # Compared normalized: on Windows the root keeps its "\\" and the path
  # read from _quarto.yml its "/".
  expect_identical(normalizePath(bib[[2]]),
                   normalizePath(file.path(refs, "packages.bib")))

  # The second time, nothing is redone and nothing is said again.
  expect_silent(bib2 <- in_project(p, .bibliography()))
  expect_identical(bib2, bib)
  # check_species() says it again, without rendering.
  expect_message(check_species(p), "Pinus halepensis")

  # italicize-species: false hands the files over untouched.
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(sub("italicize-species: true", "italicize-species: false", y),
             file.path(p, "_quarto.yml"))
  expect_identical(normalizePath(unlist(in_project(p, .bibliography()))),
                   normalizePath(file.path(refs, c("references.bib", "packages.bib"))))
})

test_that("a lockfile renv doubts is written anyway, and the doubt passed on", {
  # renv refuses a snapshot it thinks it could not restore -- packages from
  # another Bioconductor release, say -- and a paper was left with no record
  # of the environment at all.
  p <- new_project()
  calls <- list()
  local_mocked_bindings(
    snapshot = function(..., force = FALSE) {
      calls[[length(calls) + 1L]] <<- force
      if (!force) stop("aborting snapshot due to pre-flight validation failure")
      writeLines("{}", file.path(p, "renv.lock"))
      invisible(NULL)
    },
    .package = "renv")
  expect_warning(ok <- in_project(p, .record_env()), "renv.lock written")
  expect_true(ok)
  expect_identical(unlist(calls), c(FALSE, TRUE))
  expect_true(file.exists(file.path(p, "renv.lock")))

  # Any other failure is reported, not forced.
  local_mocked_bindings(snapshot = function(...) stop("disk full"),
                        .package = "renv")
  expect_warning(ok <- in_project(p, .record_env()), "Could not record.*disk full")
  expect_false(ok)
})

test_that("the title page cites as the journal does, and the main text keeps the list", {
  # A loose file inherits no bibliography from _quarto.yml: its citations
  # reached the .docx as "@Condit2002".
  p <- new_project(title = "Ants")
  writeLines(c("@article{Condit2002, author = {Condit, R.}, title = {Trees},",
               "  journal = {Science}, year = {2002}}",
               "@article{Hubbell2001, author = {Hubbell, S.}, title = {Neutral},",
               "  journal = {Science}, year = {2001}}"),
             file.path(p, "references", "references.bib"))
  ms <- readLines(file.path(p, "manuscript.qmd"))
  i  <- which(ms == "# Acknowledgements")
  ms <- append(ms, c("", "We thank the authors of @Condit2002 and @fig-x."),
               after = i)
  writeLines(ms, file.path(p, "manuscript.qmd"))
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(sub("italicize-species: true", "italicize-species: false", y),
             file.path(p, "_quarto.yml"))
  in_project(p, {
    tp <- rmarkdown::yaml_front_matter(.build_title_page())
    expect_identical(basename(tp$csl), "journal-of-ecology.csl")
    expect_true(all(file.exists(unlist(tp$bibliography))))
    expect_true(tp[["suppress-bibliography"]])
    expect_identical(.cited_in_sections(ms, .blinded_sections()), "Condit2002")
    # What only the moved sections cite stays in the main text's list.
    m <- rmarkdown::yaml_front_matter(
      .build_main_text("journal-of-ecology", "default", blinded = TRUE))
    expect_identical(m$nocite, "@Condit2002")
    m <- rmarkdown::yaml_front_matter(
      .build_main_text("journal-of-ecology", "default"))
    expect_null(m$nocite)
  })
  expect_identical(.nocite(NULL, character(0)), NULL)
  expect_identical(.nocite("@a", c("b", "c")), "@a, @b, @c")
})

test_that("render_all() is the batch, and the old names are gone", {
  # It renders into output/ like every render_*(); make_*() is what you send.
  expect_false(exists("make_all", envir = asNamespace("easypaper")))
  expect_false("make_all" %in% getNamespaceExports("easypaper"))
  expect_null(formals(make_submission)$blinded)
  expect_null(formals(render_supplementary)$blinded)
  expect_error(make_submission(blinded = FALSE, path = tempdir()),
               "unused argument")
})

test_that("blind is the argument, passed as blind everywhere", {
  # Inside the package it is always passed as blind: render_docx() goes
  # through .render(), and `blinded` would stop every render.
  expect_match(code_of(.render), "keep), blind = blinded)", fixed = TRUE)
  for (fn in list(.render, make_submission, make_preprint, render_all)) {
    expect_no_match(code_of(fn), "[^.]blinded = blinded\\)", perl = TRUE)
  }
  expect_identical(formals(make_submission)$blind, TRUE)
  expect_identical(formals(render_supplementary)$blind, FALSE)
  expect_error(make_submission(blind = NA, path = tempdir()), "TRUE or FALSE")
})

test_that("a delimiter with a space before it keeps it, in every format", {
  # Quarto reads title-delim as markdown and drops a leading space: the
  # "nature" style came out as "Figure 1| Text". A non-breaking space
  # survives.
  expect_identical(.delim_md(" |"), " |")
  expect_identical(.delim_md("."), ".")
  expect_identical(.delim_md(":"), ":")
  p <- new_project()
  in_project(p, {
    expect_identical(crossref_metadata("nature")[["title-delim"]], " |")
    expect_identical(crossref_metadata("default")[["title-delim"]], ".")
  })
  # LaTeX ignores title-delim and writes "Figure 1:" whatever it says: the
  # PDF gets the delimiter through the caption package.
  b <- .pdf_captions(list(documentclass = "article"), list(`title-delim` = "."))
  tex <- b[["include-in-header"]][[1]]$text
  expect_match(tex, "\\DeclareCaptionLabelSeparator{easypaper}{. }", fixed = TRUE)
  expect_match(tex, "\\captionsetup{labelsep=easypaper}", fixed = TRUE)
  b <- .pdf_captions(NULL, list(`title-delim` = " |"))
  expect_match(b[["include-in-header"]][[1]]$text, "{~| }", fixed = TRUE)
  # What the project already puts in the header stays, and the layout too.
  b <- .pdf_captions(.pdf_layout(list(`include-in-header` = list(text = "\\x")),
                                 list(line_numbers = TRUE)),
                     list(`title-delim` = ":"))
  expect_length(b[["include-in-header"]], 3L)
  expect_identical(b[["include-in-header"]][[1]]$text, "\\x")
  expect_identical(.pdf_captions(list(a = 1), list()), list(a = 1))
  # Both PDFs are handed it: the main text and the supplement.
  expect_match(code_of(.build_main_text), ".pdf_captions(yml$format$pdf, yml$crossref)",
               fixed = TRUE)
  expect_match(code_of(.build_supplementary),
               ".pdf_captions(yml$format$pdf, crossref_metadata(caption_style))",
               fixed = TRUE)
  expect_match(code_of(render_supplementary), "caption_style = caption_style)",
               fixed = TRUE)
})

test_that("the deposit's metadata says nothing of what was left blank", {
  # dataspice writes blank coordinates as "NA NA NA NA" and blank dates as
  # "NA/NA", which went into the deposit as if they were known.
  f <- tempfile(fileext = ".json")
  jsonlite::write_json(list(`@context` = "https://schema.org/", name = "Trees",
                            description = "", funder = NULL,
                            temporalCoverage = "NA/NA",
                            spatialCoverage = list(type = "Place", name = NULL,
                              geo = list(type = "GeoShape", box = "NA NA NA NA")),
                            keywords = list("trees")),
                       f, auto_unbox = TRUE, null = "null")
  .clean_spice(f)
  j <- jsonlite::read_json(f)
  expect_setequal(names(j), c("@context", "name", "keywords"))
  # One date known is an open interval; known coordinates stay.
  jsonlite::write_json(list(name = "Trees", temporalCoverage = "2020-01-01/NA",
                            spatialCoverage = list(type = "Place", name = "BCI",
                              geo = list(type = "GeoShape", box = "9 -79 10 -80"))),
                       f, auto_unbox = TRUE)
  .clean_spice(f)
  j <- jsonlite::read_json(f)
  expect_identical(j$temporalCoverage, "2020-01-01/..")
  expect_identical(j$spatialCoverage$geo$box, "9 -79 10 -80")
  # A name with no box keeps the place, without the box.
  jsonlite::write_json(list(name = "Trees",
                            spatialCoverage = list(type = "Place", name = "BCI",
                              geo = list(type = "GeoShape", box = "NA NA NA NA"))),
                       f, auto_unbox = TRUE)
  .clean_spice(f)
  expect_identical(jsonlite::read_json(f)$spatialCoverage, list(type = "Place", name = "BCI"))
  # Not JSON: left alone.
  writeLines("nope", f)
  expect_silent(.clean_spice(f))
  expect_identical(readLines(f), "nope")
})

test_that("edit_metadata('write') compiles clean metadata and its page", {
  p <- new_project(title = "A title", authors = "Ada Lovelace")
  write.csv(data.frame(a = 1), file.path(p, "data", "one.csv"), row.names = FALSE)
  expect_no_warning(suppressMessages(edit_metadata("write", path = p)))
  md <- file.path(p, "data", "metadata")
  j <- jsonlite::read_json(file.path(md, "dataspice.json"))
  expect_null(j$temporalCoverage)
  expect_null(j$spatialCoverage)
  expect_identical(j$name, "A title")
  expect_true(file.exists(file.path(md, "index_metadata.html")))
})
