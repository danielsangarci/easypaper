test_that("the project's copy of convert_data.R is identical to the package's", {
  # The package exports convert_data() and create_paper() writes the same file
  # into every project, so a project keeps working with easypaper uninstalled.
  # Two copies of one function drift apart unless something says so.
  src <- test_path("..", "..", "R", "convert_data.R")
  # R CMD check runs the tests against the installed package, where the sources
  # are not beside them. This guard is what makes the test useful locally.
  skip_if_not(file.exists(src), "package sources not next to the tests")
  pkg <- readLines(src, warn = FALSE)
  tpl <- readLines(
    system.file("template", "R", "convert_data.R", package = "easypaper"),
    warn = FALSE)
  expect_identical(tpl, pkg)
})

test_that("convert_data() converts, copies and reports, into one folder", {
  p <- tempfile("cd")
  dir.create(file.path(p, "originals", "deep"), recursive = TRUE)
  old <- setwd(p); on.exit(setwd(old), add = TRUE)

  utils::write.csv(data.frame(a = 1:2), "originals/plain.csv", row.names = FALSE)
  writeLines("x", "originals/notes.txt")
  writeLines("y", "originals/probe.gpkg")   # already open: copied
  writeLines("z", "originals/spectra.raw")  # neither: named

  written <- suppressMessages(convert_data("originals"))

  expect_true(file.exists(file.path(p, "data", "plain.csv")))
  expect_true(file.exists(file.path(p, "data", "notes.txt")))
  expect_true(file.exists(file.path(p, "data", "probe.gpkg")))
  expect_false(file.exists(file.path(p, "data", "spectra.raw")))
  expect_length(written, 3L)
  # The originals are only ever read.
  expect_true(file.exists(file.path(p, "originals", "plain.csv")))

  said <- paste(utils::capture.output(convert_data("originals"),
                                      type = "message"), collapse = " ")
  expect_match(said, "spectra.raw")
  expect_match(said, "already up to date")
})

test_that("convert_data() refuses to overwrite one original with another", {
  p <- tempfile("cd")
  dir.create(file.path(p, "originals", "deep"), recursive = TRUE)
  old <- setwd(p); on.exit(setwd(old), add = TRUE)

  utils::write.csv(data.frame(a = "top"), "originals/x.csv", row.names = FALSE)
  utils::write.csv(data.frame(a = "deep"), "originals/deep/x.csv",
                   row.names = FALSE)
  expect_warning(suppressMessages(convert_data("originals")),
                 "was refused -- both give x.csv")
  # Whichever comes first alphabetically by path keeps the name: "deep/x.csv"
  # sorts before "x.csv". What matters is that the other is refused, not lost
  # under it, and that the warning says which is which.
  expect_identical(utils::read.csv(file.path(p, "data", "x.csv"))$a, "deep")
  expect_true(file.exists(file.path(p, "originals", "x.csv")))
})

test_that("convert_data() will not copy a folder onto itself", {
  p <- tempfile("cd")
  dir.create(file.path(p, "data"), recursive = TRUE)
  old <- setwd(p); on.exit(setwd(old), add = TRUE)

  utils::write.csv(data.frame(a = 1), "data/already.csv", row.names = FALSE)
  expect_message(convert_data("data"), "Nothing to convert")
  expect_length(list.files(file.path(p, "data")), 1L)
})
