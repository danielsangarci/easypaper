# Contributing to easypaper

Thank you for wanting to help. This is how to report a problem or propose a
change.

## Reporting a problem

Open an [issue](https://github.com/danielsangarci/easypaper/issues) with:

* what you ran, and what happened instead of what you expected;
* the output of `sessionInfo()` and of `quarto::quarto_version()`, and your
  system (Windows, macOS or Linux): many problems of a render depend on the
  version of Quarto, which ships inside RStudio and lags behind;
* if you can, a project that shows it: `create_example_paper()` or
  `create_paper()` in a temporary folder, with the smallest change that makes
  it fail.

## Fixing typos

Typos in the documentation can be fixed directly on GitHub, in the _source_:
the roxygen2 comments of the `.R` files in `R/`, not the `.Rd` files in `man/`,
which are generated from them. The first line of each `.Rd` file says which
`.R` file it comes from.

## Bigger changes

Open an issue first, so we can agree that the change is needed and how it
fits before you spend time on it. Then:

* Fork the repository and clone it, for instance with
  `usethis::create_from_github("danielsangarci/easypaper", fork = TRUE)`.
* Install the development dependencies with `devtools::install_dev_deps()`,
  and check that `devtools::check()` passes before you start.
* Make the change on a branch of its own (`usethis::pr_init("short-name")`),
  with tests, and a bullet at the top of `NEWS.md` if users will notice it.
* Push it and open a pull request (`usethis::pr_push()`), saying in its body
  which issue it fixes: `Fixes #12`.

### What the checks expect

* **No test reaches the network.** GBIF and Wikipedia are answered from the
  caches in `tests/testthat/fixtures/`; a test that needs a new answer fails
  instead of going online. Regenerate the caches, with a connection, by
  running `dev/species_fixtures.R`.
* **CRAN has no Quarto**, so the tests that render skip there. The
  [Render](https://github.com/danielsangarci/easypaper/actions/workflows/render.yaml)
  workflow renders every function on the worked example and on the template,
  on Windows and macOS, with the Quarto of RStudio and the latest one: a
  change to a render should pass it.
* **Nothing is written outside `tempdir()`** by the examples and the tests,
  and no exported function writes anywhere it was not told to: the project is
  the one `path` or `set_paper()` names.

### Style

* Code follows the [tidyverse style guide](https://style.tidyverse.org), and
  reads like the code around it.
* Documentation is written with [roxygen2](https://roxygen2.r-lib.org), in
  Markdown; run `devtools::document()` after changing it.
* Tests use [testthat](https://testthat.r-lib.org); a pull request with tests
  is easier to accept.

## Code of Conduct

Please note that easypaper is released with a
[Contributor Code of Conduct](https://github.com/danielsangarci/easypaper/blob/main/CODE_OF_CONDUCT.md).
By contributing to this project you agree to abide by its terms.
