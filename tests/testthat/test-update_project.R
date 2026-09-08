# A project as an earlier version would have left it: the stamp says 0.1.0,
# one build file is missing, another has drifted, a rule is gone from the
# .gitignore, and the author's own files carry edits that must survive.
old_project <- function() {
  p <- tempfile("paper")
  suppressMessages(create_paper(p, git = FALSE))
  l <- readLines(file.path(p, "make.R"))
  l[1] <- sub("easypaper [0-9.]+", "easypaper 0.1.0", l[1])
  writeLines(c(l, "# drifted"), file.path(p, "make.R"))
  unlink(file.path(p, "R", "convert_data.R"))
  cat("\n# drifted\n", file = file.path(p, "run.R"), append = TRUE)
  gi <- readLines(file.path(p, ".gitignore"))
  writeLines(c(gi[gi != "cache/"], "my_scratch/"), file.path(p, ".gitignore"))
  cat("\nmy_helper <- function() 1\n", file = file.path(p, "R", "setup.R"),
      append = TRUE)
  writeLines("My introduction.", file.path(p, "_sections", "2_introduction.qmd"))
  p
}

all_md5 <- function(p) {
  tools::md5sum(list.files(p, recursive = TRUE, full.names = TRUE,
                           all.files = TRUE))
}

test_that("dry_run lists what drifted and writes nothing", {
  p <- old_project()
  before <- all_md5(p)
  said <- capture_messages(plan <- update_project(p, dry_run = TRUE))
  expect_true(any(grepl("written by easypaper 0.1.0", said)))
  expect_true(any(grepl("Would write", said)))
  expect_identical(plan$action[plan$file == "R/convert_data.R"], "add")
  expect_identical(plan$action[plan$file == "run.R"], "update")
  expect_identical(plan$action[plan$file == ".gitignore"], "append")
  expect_identical(plan$action[plan$file == "R/submission.R"], "same")
  expect_identical(plan$action[plan$file == "make.R"], "update")
  expect_false(any(grepl("^_sections|^R/setup[.]R$|_quarto|manuscript", plan$file)))
  expect_identical(all_md5(p), before)
})

test_that("the build files are refreshed and everything else is left alone", {
  p <- old_project()
  said <- capture_messages(update_project(p))
  tpl <- system.file("template", package = "easypaper")

  expect_identical(readLines(file.path(p, "R", "convert_data.R")),
                   readLines(file.path(tpl, "R", "convert_data.R")))
  expect_identical(readLines(file.path(p, "run.R")),
                   readLines(file.path(tpl, "run.R")))
  expect_true(any(grepl("my_helper", readLines(file.path(p, "R", "setup.R")))))
  expect_identical(readLines(file.path(p, "_sections", "2_introduction.qmd")),
                   "My introduction.")
  gi <- readLines(file.path(p, ".gitignore"))
  expect_true("my_scratch/" %in% gi)
  expect_true("cache/" %in% gi)

  # make.R was replaced by a fresh copy, and the stamp still knows who
  # created the project.
  top <- readLines(file.path(p, "make.R"), n = 1L)
  expect_match(top, "created by easypaper 0.1.0, updated to")
  expect_false(any(grepl("# drifted", readLines(file.path(p, "make.R")))))
  expect_match(top, as.character(utils::packageVersion("easypaper")),
               fixed = TRUE)
  expect_no_error(parse(file.path(p, "make.R")))
  expect_true(any(grepl("No repository", said)))

  expect_message(update_project(p), "nothing to update")
})

test_that("a project with uncommitted changes is refused; a clean one goes", {
  skip_if(!nzchar(Sys.which("git")), "git is not installed")
  p <- old_project()
  .git(c("init", "-q", shQuote(p)))
  who <- .git(c("config", "user.email"), dir = p)
  skip_if(!who$ok || !length(who$out) || !nzchar(who$out[1]),
          "git has no identity configured")

  expect_error(update_project(p), "uncommitted")
  .git(c("add", "-A"), dir = p)
  .git(c("commit", "-q", "-m", shQuote("as an old version left it")), dir = p)
  expect_message(update_project(p), "git diff")
  changed <- .git(c("status", "--porcelain"), dir = p)$out
  expect_true(any(grepl("run[.]R", changed)))
  expect_false(any(grepl("_sections", changed)))
})

test_that("what is not a project, or comes from the future, is refused", {
  expect_error(update_project(tempfile()), "not an easypaper project")
  p <- tempfile("paper")
  suppressMessages(create_paper(p, git = FALSE))
  l <- readLines(file.path(p, "make.R"))
  l[1] <- sub("easypaper [0-9.]+", "easypaper 99.0.0", l[1])
  writeLines(l, file.path(p, "make.R"))
  expect_error(update_project(p), "update the package")
})

test_that("a project with no stamp is updated and stamped", {
  p <- tempfile("paper")
  suppressMessages(create_paper(p, git = FALSE))
  writeLines(readLines(file.path(p, "make.R"))[-(1:3)], file.path(p, "make.R"))
  expect_message(update_project(p), "unknown version")
  expect_match(readLines(file.path(p, "make.R"), n = 1L),
               paste0("^# Structure created by easypaper ",
                      utils::packageVersion("easypaper"), " on"))
})

test_that("open formats added to the project's convert_data.R are named", {
  p <- tempfile("paper")
  suppressMessages(create_paper(p, git = FALSE))
  l <- readLines(file.path(p, "make.R"))
  l[1] <- sub("easypaper [0-9.]+", "easypaper 0.1.0", l[1])
  writeLines(l, file.path(p, "make.R"))
  f <- file.path(p, "R", "convert_data.R")
  cd <- readLines(f)
  i <- grep("^[.]cd_open_formats <- c\\($", cd)
  expect_length(i, 1L)
  writeLines(append(cd, '  "las", "xyz",', after = i), f)
  expect_identical(setdiff(.open_formats_in(f), .cd_open_formats), c("las", "xyz"))

  said <- capture_messages(update_project(p, dry_run = TRUE))
  expect_true(any(grepl("las, xyz", said)))
})

test_that("what has to be done by hand is listed, and only when it applies", {
  p <- old_project()
  dir.create(file.path(p, "data", "csv"))
  file.create(file.path(p, "R", "xlsx_to_csv.R"))
  said <- capture_messages(update_project(p, dry_run = TRUE))
  expect_true(any(grepl("data/csv", said)))
  expect_true(any(grepl("xlsx_to_csv", said)))
  # Nothing is deleted, even a file the new version does not use.
  suppressMessages(update_project(p))
  expect_true(file.exists(file.path(p, "R", "xlsx_to_csv.R")))
  expect_true(dir.exists(file.path(p, "data", "csv")))

  q <- tempfile("paper")
  suppressMessages(create_paper(q, git = FALSE))
  expect_no_message(update_project(q, dry_run = TRUE), message = "by hand")
})

test_that("the stamp survives a round trip and is never doubled", {
  f <- tempfile(fileext = ".R")
  writeLines(c("x <- 1", "y <- 2"), f)
  .stamp_version(f)
  .stamp_version(f)
  l <- readLines(f)
  expect_identical(sum(grepl("^# Structure created", l)), 1L)
  expect_identical(.strip_stamp(l), c("x <- 1", "y <- 2"))
  info <- .stamp_info(f)
  expect_identical(info$created, info$current)
  expect_null(.stamp_info(tempfile()))
})
