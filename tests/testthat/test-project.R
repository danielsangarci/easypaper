# How a function finds the project it works on, and what the project tells
# it: its settings, its Word templates, its citation styles.

test_that("the project is found from any folder inside it", {
  p <- new_project()
  root <- normalizePath(p)
  expect_identical(.find_root(p), root)
  expect_identical(.find_root(file.path(p, "_sections")), root)
  expect_identical(.find_root(file.path(p, "data", "metadata")), root)
  withr_dir <- function(d, code) {
    old <- setwd(d)
    on.exit(setwd(old))
    force(code)
  }
  expect_identical(withr_dir(file.path(p, "R"), .find_root()), root)
})

test_that("outside a project it says what a project is", {
  d <- tempfile("nothing")
  dir.create(d)
  expect_error(.find_root(d), "_quarto.yml and manuscript.qmd")
  expect_error(.find_root(file.path(d, "missing")), "not a folder")
  expect_error(check_citations(d), "No easypaper project")
})

test_that("a nested call keeps the project of the call that made it", {
  # render_docx(path = "~/paper") calls render_supplementary(), which is given
  # no path: it must render that paper's supplement, not the working
  # directory's.
  p <- new_project()
  q <- new_project()
  old <- setwd(q)
  on.exit(setwd(old), add = TRUE)
  outer <- function(path) {
    .enter_project(path)
    inner <- function(path = ".") {
      .enter_project(path)
      .p()
    }
    inner()
  }
  expect_identical(outer(p), normalizePath(p))
  # And the project is forgotten when the outermost call ends, error or not.
  expect_null(.ep$root)
  expect_error(outer(file.path(tempdir(), "no-such-paper")))
  expect_null(.ep$root)
  expect_identical(list_journals(), "journal-of-ecology")
})

test_that("a project's settings come from the easypaper: block of _quarto.yml", {
  p <- new_project()
  in_project(p, {
    expect_true(.config("italicize-species"))
    expect_identical(.config("no-such-setting", "fallback"), "fallback")
  })
  # A project with no block at all has the defaults.
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(y[seq_len(grep("^# --- easypaper", y) - 1L)],
             file.path(p, "_quarto.yml"))
  in_project(p, {
    expect_null(.config("italicize-species"))
    expect_identical(.blinded_sections(), BLINDED_SECTIONS)
  })
})

test_that("the Word templates ship with the package, and a project's own win", {
  p <- new_project()
  in_project(p, {
    for (w in c("manuscript", "supplement", "letter")) {
      f <- .word_template(w)
      expect_true(file.exists(f), info = w)
      expect_identical(dirname(f), system.file("word", package = "easypaper"))
    }
  })
  dir.create(file.path(p, "format"))
  file.copy(system.file("word", "word_cover_letter.docx", package = "easypaper"),
            file.path(p, "format", "word_cover_letter.docx"))
  in_project(p, {
    expect_identical(.word_template("letter"),
                     file.path(normalizePath(p), "format", "word_cover_letter.docx"))
    expect_identical(dirname(.word_template("manuscript")),
                     system.file("word", package = "easypaper"))
  })
})

test_that("citation styles are read from references/", {
  p <- new_project()
  csl <- file.path(p, "references", "journal-of-ecology.csl")
  file.copy(csl, file.path(p, "references", "ecology.csl"))
  in_project(p, {
    expect_identical(list_journals(), c("ecology", "journal-of-ecology"))
    expect_identical(.csl_path("ecology"),
                     file.path(normalizePath(p), "references", "ecology.csl"))
    expect_error(.csl_path("nature"), "add_journal\\(\"nature\"\\)")
    expect_error(.csl_path("nature"), "Available: ecology, journal-of-ecology")
  })
})

test_that("a style the manuscript names somewhere else is found there", {
  p <- new_project()
  dir.create(file.path(p, "styles"))
  file.rename(file.path(p, "references", "journal-of-ecology.csl"),
              file.path(p, "styles", "journal-of-ecology.csl"))
  ms <- readLines(file.path(p, "manuscript.qmd"))
  writeLines(sub("^csl: .*$", "csl: styles/journal-of-ecology.csl", ms),
             file.path(p, "manuscript.qmd"))
  in_project(p, {
    expect_identical(.resolve_journal(NULL), "journal-of-ecology")
    expect_true(file.exists(.csl_path("journal-of-ecology")))
  })
})

test_that("caption styles of the project's own are used, the built-in ones kept", {
  p <- new_project()
  y <- readLines(file.path(p, "_quarto.yml"))
  i <- grep("^  trackdown-folder:", y)
  writeLines(append(y, c("  caption-styles:",
                         "    ecography: {fig: \"Fig.\", sfig: \"Fig. S\"}"),
                    after = i),
             file.path(p, "_quarto.yml"))
  in_project(p, {
    cr <- crossref_metadata("ecography")
    expect_identical(cr[["fig-prefix"]], "Fig.")
    # What the style does not give comes from the default.
    expect_identical(cr[["tbl-prefix"]], "Table")
    expect_identical(cr[["title-delim"]], ".")
    sfig <- Filter(function(k) identical(k$key, "sfig"), cr$custom)[[1]]
    expect_identical(sfig[["reference-prefix"]], "Fig. S")
    expect_identical(crossref_metadata("nature")[["title-delim"]], "\u00a0|")
    expect_error(crossref_metadata("nope"), "Available: default, abbrev, colon, compact, nature, ecography")
  })
})

test_that("every built-in caption style writes what its name promises", {
  p <- new_project()
  in_project(p, {
    want <- list(abbrev  = c("Fig.",   "Table", "Fig. S",   "Table S", "."),
                 colon   = c("Figure", "Table", "Figure S", "Table S", ":"),
                 compact = c("Fig.",   "Table", "Fig. S",   "Table S", ":"),
                 # The space before the bar is non-breaking: Quarto drops
                 # a plain one.
                 nature  = c("Figure", "Table", "Figure S", "Table S", "\u00a0|"))
    for (st in names(want)) {
      cr <- crossref_metadata(st)
      pref <- function(key) {
        Filter(function(k) identical(k$key, key), cr$custom)[[1]][["reference-prefix"]]
      }
      expect_identical(c(cr[["fig-title"]], cr[["tbl-title"]], pref("sfig"),
                         pref("stbl"), cr[["title-delim"]]), want[[st]], info = st)
      expect_identical(cr[["fig-prefix"]], cr[["fig-title"]], info = st)
      expect_identical(cr[["tbl-prefix"]], cr[["tbl-title"]], info = st)
      # Quarto reads no space-before-numbering for figures and tables: only
      # the supplement's own types drop the space, and they keep doing so.
      expect_null(cr[["space-before-numbering"]])
      for (k in cr$custom) expect_false(k[["space-before-numbering"]], info = st)
    }
  })
})

test_that("a generated format block is never empty", {
  p <- new_project()
  in_project(p, {
    expect_identical(.format_block(NULL, "html"), "default")
    expect_identical(.format_block(list(toc = TRUE), "html"), list(toc = TRUE))
    b <- .format_block("default", "docx")
    expect_true(file.exists(b$`reference-doc`))
  })
})

test_that("every exported function works on the project `path` names", {
  # Anything that builds a project takes the project as its last argument,
  # `path`, and defaults to the working directory.
  builds <- c("render_docx", "render_pdf", "render_html", "render_supplementary",
              "render_all", "preview", "make_submission",
              "make_preprint",
              "check_citations", "check_crossrefs", "check_packages",
              "check_title", "check_data", "check_renv", "check_species",
              "sync_licenses", "sync_metadata", "edit_metadata", "export_code",
              "export_figure_formats", "clean_cache", "list_journals",
              "td_upload", "td_update", "td_download", "add_journal",
              "affiliations", "manuscript_stats", "deposit_zenodo",
              "check_species_text")
  for (fn in builds) {
    f <- formals(getExportedValue("easypaper", fn))
    expect_identical(f$path, ".", info = fn)
  }
  expect_setequal(setdiff(getNamespaceExports("easypaper"), builds),
                  c("create_paper", "create_example_paper", "convert_data",
                    "italicize_species"))
})
