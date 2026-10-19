# How a function finds the project it works on, and what the project tells
# it: its settings, its Word templates, its citation styles.

test_that("the project is found from any folder inside it", {
  p <- new_project()
  root <- normalizePath(p, winslash = "/")
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
    inner <- function(path = NULL) {
      .enter_project(path)
      .p()
    }
    inner()
  }
  expect_identical(outer(p), normalizePath(p, winslash = "/"))
  # And the project is forgotten when the outermost call ends, error or not.
  expect_null(.ep$root)
  expect_error(outer(file.path(tempdir(), "no-such-paper")))
  expect_null(.ep$root)
  expect_identical(list_journals(), "journal-of-ecology")
})

test_that("nothing is written into the working directory's project unasked", {
  # CRAN's policy: a package writes where it is told to, or, in an
  # interactive session, with the user's confirmation.
  p <- new_project()
  old <- setwd(p)
  on.exit(setwd(old), add = TRUE)
  .ep$allowed <- NULL
  on.exit(.ep$allowed <- NULL, add = TRUE)
  ls_out <- function() list.files(file.path(p, "output"))

  # A script: nobody to ask, so the project has to be named, and nothing is
  # written meanwhile.
  local_mocked_bindings(.interactive = function() FALSE,
                        .ask_yes_no = function(q) stop("asked"))
  expect_error(export_code(), 'export_code\\(\\) writes into a project.*export_code\\(path = "."\\)')
  expect_error(easypaper::export_code(), "export_code\\(\\) writes into a project")
  expect_length(ls_out(), 0L)
  # Named, it writes, without asking; and what only reads never asks.
  suppressMessages(export_code(path = "."))
  expect_true("analysis_code.R" %in% ls_out())
  expect_identical(list_journals(), "journal-of-ecology")
  expect_no_error(suppressMessages(check_citations()))

  # An interactive session: asked once, the project named, and a no writes
  # nothing.
  unlink(file.path(p, "output"), recursive = TRUE)
  asked <- character()
  answer <- FALSE
  local_mocked_bindings(.interactive = function() TRUE,
                        .ask_yes_no = function(q) { asked <<- c(asked, q); answer })
  # The project is named in a message, and the prompt is the question alone.
  msgs <- testthat::capture_messages(
    expect_error(export_code(), "Nothing was written"))
  expect_length(asked, 1L)
  expect_identical(asked, "Allow it for this session?")
  expect_match(paste(msgs, collapse = ""), normalizePath(p, winslash = "/"),
               fixed = TRUE)
  expect_false(dir.exists(file.path(p, "output")))
  # A yes holds for the session: the next calls, nested ones too, do not ask.
  answer <- TRUE
  suppressMessages(export_code())
  suppressMessages(export_figure_formats())
  expect_length(asked, 2L)
  expect_true("analysis_code.R" %in% ls_out())
  # Another project is asked about on its own.
  q <- new_project()
  setwd(q)
  msgs <- testthat::capture_messages(export_code())
  expect_length(asked, 3L)
  expect_match(paste(msgs, collapse = ""), normalizePath(q, winslash = "/"),
               fixed = TRUE)
})

test_that("a call says which Quarto it uses once, however many renders it runs", {
  # render_all() renders the .docx and the .pdf, each with its supplement;
  # make_submission() renders the main text, the title page and the
  # supplement. Each render checks Quarto, and the line came out every time.
  fake <- tempfile("quarto")
  file.create(fake)
  local_mocked_bindings(quarto_path = function(...) fake,
                        quarto_version = function(...) numeric_version("1.9.38"),
                        .package = "quarto")
  p <- new_project()
  said <- function(code) {
    out <- character()
    withCallingHandlers(code, message = function(m) {
      out <<- c(out, conditionMessage(m))
      invokeRestart("muffleMessage")
    })
    sum(grepl("^quarto 1.9.38", out))
  }
  render <- function(path = NULL) {
    .enter_project(path)
    .check_quarto()
  }
  render_all <- function(path) {
    .enter_project(path)
    .check_quarto(); render(); render(); render()
  }
  expect_identical(said(render_all(p)), 1L)
  # The next call says it again, and so does one that failed half way.
  expect_identical(said(render_all(p)), 1L)
  expect_error(said(local({ .enter_project(p); .check_quarto(); stop("half way") })))
  expect_null(.ep$said)
  expect_identical(said(render(p)), 1L)
  # Outside any project it is said every time.
  expect_identical(said({ .check_quarto(); .check_quarto() }), 2L)
  expect_null(.ep$said)
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
                     file.path(normalizePath(p, winslash = "/"), "format",
                               "word_cover_letter.docx"))
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
                     file.path(normalizePath(p, winslash = "/"), "references",
                               "ecology.csl"))
    expect_error(.csl_path("nature"), "add_journal\\(\"nature\"\\)")
    expect_error(.csl_path("nature"), "Available: ecology, journal-of-ecology")
  })
})

test_that("the paths handed to Quarto have no backslash", {
  # Pandoc reads a backslash in the metadata as an escape: on Windows
  # C:\Users\Ana Lopez\paper/references/x.csl reached it as C:Lopez... and
  # the render stopped, the .csl not found.
  expect_identical(.slashes("C:\\Users\\Ana Lopez\\paper/references/x.csl"),
                   "C:/Users/Ana Lopez/paper/references/x.csl")
  p <- new_project()
  in_project(p, {
    expect_false(grepl("\\", .p(), fixed = TRUE))
    expect_false(grepl("\\", .csl_path("journal-of-ecology"), fixed = TRUE))
    # The italic copies go to tempdir(), which on Windows has backslashes.
    local_mocked_bindings(.italic_bibliography = function(f) {
      "C:\\Temp\\Rtmp1\\references_italic.json"
    })
    expect_identical(.bibliography()[[1]],
                     "C:/Temp/Rtmp1/references_italic.json")
  })
})

test_that("a render that fails says so, not what cli made of its log", {
  # The quarto package puts Quarto's log into a cli message, and the
  # {.short-title} of the title broke it.
  local_mocked_bindings(
    quarto_render = function(...) {
      # What cli says when it meets {.short-title} in the log.
      stop("Invalid cli literal: `{.short-ti...}` starts with a dot.")
    },
    .package = "quarto")
  expect_error(.quarto_render("tmp_main_text.qmd"),
               "Quarto could not render tmp_main_text.qmd")
  local_mocked_bindings(quarto_render = function(...) stop("No such file"),
                        .package = "quarto")
  expect_error(.quarto_render("x.qmd"), "No such file")
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
  # `path`, NULL by default: the working directory's project, written into
  # only with permission.
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
    expect_true("path" %in% names(f), info = fn)
    expect_null(f$path, info = fn)
  }
  expect_setequal(setdiff(getNamespaceExports("easypaper"), builds),
                  c("create_paper", "create_example_paper", "convert_data",
                    "italicize_species", "write_packages_bib"))
})

test_that("a file that cannot be moved into place stops the call", {
  # On Windows a .docx open in Word cannot be replaced: file.rename() only
  # warned, and "Written:" named a file that was the old one.
  d <- tempfile("move_")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  to <- file.path(d, "manuscript.docx")
  expect_error(suppressWarnings(.move(file.path(d, "missing.docx"), to)),
               "If it is open")
  writeLines("new", f <- file.path(d, "tmp.docx"))
  writeLines("old", to)
  expect_identical(.move(f, to), to)
  expect_identical(readLines(to), "new")
})
