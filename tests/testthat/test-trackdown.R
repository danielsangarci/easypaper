# The td_*() functions hand a section to trackdown, which needs a Google
# account: trackdown's own functions are replaced here by ones that record
# what they were given, so what is checked is what easypaper passes on.

# Record every call to trackdown, by function, until the calling test ends.
record_trackdown <- function(env = parent.frame()) {
  calls <- new.env()
  keep <- function(what) {
    force(what)
    function(...) {
      assign(what, list(...), envir = calls)
      invisible(what)
    }
  }
  local_mocked_bindings(upload_file = keep("upload"),
                        update_file = keep("update"),
                        download_file = keep("download"),
                        .package = "trackdown", .env = env)
  local_mocked_bindings(.td_ready = function() TRUE, .env = env)
  calls
}

test_that("a section goes to Google Docs under the name of the manuscript", {
  skip_if_not_installed("trackdown")
  p <- new_project()
  calls <- record_trackdown()
  expect_identical(td_upload("02", path = p), "upload")
  up <- calls$upload
  expect_identical(normalizePath(up$file),
                   normalizePath(file.path(p, "_sections", "02_introduction.qmd")))
  expect_identical(up$gfile, "manuscript_02_introduction")
  # No folder named: the root of the Drive, as _quarto.yml leaves it.
  expect_identical(up$gpath, "")
  expect_true(up$hide_code)

  # update and download, on the same file and the same Google Doc.
  td_update("02_introduction", hide_code = FALSE, path = p)
  expect_identical(calls$update$gfile, "manuscript_02_introduction")
  expect_false(calls$update$hide_code)
  td_download("02", path = p)
  expect_identical(calls$download$file, up$file)
  expect_identical(calls$download$gfile, "manuscript_02_introduction")
  expect_null(calls$download$hide_code)
})

test_that("the Drive folder is the call's, or else the one of _quarto.yml", {
  skip_if_not_installed("trackdown")
  p <- new_project()
  y <- readLines(file.path(p, "_quarto.yml"))
  writeLines(sub('^  trackdown-folder: ""$', '  trackdown-folder: "papers/ants"', y),
             file.path(p, "_quarto.yml"))
  calls <- record_trackdown()
  td_upload("03", path = p)
  expect_identical(calls$upload$gpath, "papers/ants")
  td_upload("03", gpath = "elsewhere", path = p)
  expect_identical(calls$upload$gpath, "elsewhere")
})

test_that("a section that is not one, or not only one, is refused naming them all", {
  skip_if_not_installed("trackdown")
  p <- new_project()
  calls <- record_trackdown()
  expect_error(td_upload("99", path = p),
               "Unknown section: '99'. Available: 01_abstract, 02_introduction")
  # "04" starts both results files.
  expect_error(td_upload("04", path = p), "Ambiguous section: '04'")
  expect_error(td_upload(c("02", "03"), path = p), "single")
  expect_null(calls$upload)
})

test_that("without the trackdown that reads .qmd it says what to install", {
  p <- new_project()
  local_mocked_bindings(.td_ready = function() FALSE)
  expect_error(td_upload("02", path = p),
               'remotes::install_github("ClaudioZandonella/trackdown")',
               fixed = TRUE)
})

test_that("with no project named, nothing is uploaded or downloaded", {
  skip_if_not_installed("trackdown")
  p <- new_project()
  old <- setwd(p)
  on.exit(setwd(old), add = TRUE)
  prev <- suppressMessages(set_paper(NULL))
  on.exit(suppressMessages(set_paper(prev)), add = TRUE)
  calls <- record_trackdown()
  expect_error(td_download("02"), "none is named")
  expect_null(calls$download)
})
