test_that("the names in the titles of package references are kept as written", {
  # A style in sentence case printed "Vegan: Community ecology package" and
  # "Automate reproducible quarto manuscripts": the package name capitalised
  # as the first word, the software it names lowercased.
  expect_identical(
    .protect_title("  title = {easypaper: Automate Reproducible Quarto Manuscripts},",
                   "Quarto"),
    "  title = {{easypaper}: Automate Reproducible {Quarto} Manuscripts},")
  # R on its own, at the end of a title too; not inside a word.
  expect_identical(
    .protect_title("  title = {knitr: Dynamic Report Generation in R},"),
    "  title = {{knitr}: Dynamic Report Generation in {R}},")
  expect_identical(.protect_title("  title = {R: A Language and Environment},"),
                   "  title = {{R}: A Language and Environment},")
  expect_identical(.protect_title("  title = {here: Rasters and Rules},"),
                   "  title = {{here}: Rasters and Rules},")
  # Twice is once.
  x <- .protect_title("  title = {easypaper: Quarto in R},", "Quarto")
  expect_identical(.protect_title(x, "Quarto"), x)
  # Only title lines, and each entry with its own package's names.
  l <- c("@Manual{R-easypaper,", "  title = {easypaper: Reproducible Quarto Manuscripts},",
         "  note = {R package version 0.1.0},", "}")
  out <- .protect_bib_titles(l)
  expect_identical(out[2], "  title = {{easypaper}: Reproducible {Quarto} Manuscripts},")
  expect_identical(out[3], l[3])
  # The quoted names come from the package's DESCRIPTION.
  expect_identical(.quoted_names("easypaper"), "Quarto")
  expect_identical(.quoted_names("no.such.package"), character(0))
})

test_that("write_packages_bib() writes knitr's entries, protected", {
  f <- tempfile(fileext = ".bib")
  expect_identical(write_packages_bib(c("base", "knitr"), f), f)
  l <- readLines(f)
  expect_true(any(grepl("@Manual{R-knitr,", l, fixed = TRUE)))
  expect_true(any(grepl("title = {{knitr}:", l, fixed = TRUE)))
  expect_true(any(grepl("title = {{R}:", l, fixed = TRUE)))
  # The template calls it, not knitr directly.
  ms <- readLines(system.file("template", "manuscript.qmd", package = "easypaper"))
  expect_true(any(grepl("easypaper::write_packages_bib(", ms, fixed = TRUE)))
  expect_false(any(grepl("^knitr::write_bib", ms)))
})
