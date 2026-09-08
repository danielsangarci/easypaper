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

test_that("every open format the code accepts is named in the data README", {
  # That README travels inside every project and is where someone looks up
  # what convert_data() will copy. A format added to the vector and not to the
  # table is a format nobody knows about.
  txt <- paste(readLines(system.file("template", "data", "README.md",
                                     package = "easypaper"), warn = FALSE),
               collapse = " ")
  missing <- .cd_open_formats[
    !vapply(.cd_open_formats,
            function(e) grepl(paste0(".", e), txt, fixed = TRUE), logical(1))]
  expect_identical(missing, character(0))
})

test_that("inputs are checked before anything is written", {
  p <- tempfile("cd")
  dir.create(p)
  old <- setwd(p); on.exit(setwd(old), add = TRUE)
  expect_error(convert_data(c("a", "b")), "single non-empty")
  expect_error(convert_data(""), "single non-empty")
  expect_error(convert_data("nothing_here"), "nothing at")
  expect_error(convert_data(".", overwrite = "yes"), "TRUE or FALSE")
  expect_error(convert_data(".", also = 1), "`also`")
  expect_error(convert_data(".", to = character(0)), "`to`")
  expect_false(dir.exists(file.path(p, "data")))
})

test_that("a workbook becomes one .csv per sheet, and a .sav one .csv", {
  skip_if_not_installed("readxl")
  skip_if_not_installed("haven")
  p <- tempfile("cd")
  dir.create(file.path(p, "originals"), recursive = TRUE)
  old <- setwd(p); on.exit(setwd(old), add = TRUE)
  file.copy(readxl::readxl_example("datasets.xlsx"), "originals/datasets.xlsx")
  file.copy(system.file("examples", "iris.sav", package = "haven"),
            "originals/iris.sav")

  said <- capture_messages(written <- convert_data("originals"))
  sheets <- readxl::excel_sheets("originals/datasets.xlsx")
  expect_setequal(basename(written),
                  c(paste0("datasets_", make.names(sheets), ".csv"), "iris.csv"))
  expect_identical(nrow(utils::read.csv("data/datasets_mtcars.csv")), 32L)
  # The values travelled, the labels did not, and the message says so.
  expect_true(is.numeric(utils::read.csv("data/iris.csv")$Species))
  expect_true(any(grepl("labelled format", said)))
})

test_that("a file that cannot be read is named, and the batch goes on", {
  skip_if_not_installed("readxl")
  p <- tempfile("cd")
  dir.create(file.path(p, "originals"), recursive = TRUE)
  old <- setwd(p); on.exit(setwd(old), add = TRUE)
  writeLines("not a workbook", "originals/broken.xlsx")
  utils::write.csv(data.frame(a = 1), "originals/fine.csv", row.names = FALSE)

  expect_warning(written <- suppressMessages(convert_data("originals")),
                 "broken.xlsx could not be read")
  expect_identical(basename(written), "fine.csv")
})

test_that("a working directory with regex characters in its name is fine", {
  # The closing message used the working directory as a regular expression.
  p <- file.path(tempfile("cd"), "a+b (c).d")
  dir.create(file.path(p, "originals"), recursive = TRUE)
  old <- setwd(p); on.exit(setwd(old), add = TRUE)
  utils::write.csv(data.frame(a = 1), "originals/x.csv", row.names = FALSE)
  expect_message(convert_data("originals"), "^data/ updated")
  expect_message(convert_data("originals", to = "clean"), "^clean/ updated")
})

test_that("names that differ only in case are one name", {
  # The deposit has to unpack on a file system that cannot tell them apart.
  p <- tempfile("cd")
  dir.create(file.path(p, "originals", "deep"), recursive = TRUE)
  old <- setwd(p); on.exit(setwd(old), add = TRUE)
  utils::write.csv(data.frame(a = 1), "originals/deep/Counts.csv",
                   row.names = FALSE)
  utils::write.csv(data.frame(a = 2), "originals/counts.csv",
                   row.names = FALSE)
  expect_warning(suppressMessages(convert_data("originals")), "was refused")
  expect_length(list.files("data"), 1L)
})
