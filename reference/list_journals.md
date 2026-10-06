# The journals a project can render for

Every `.csl` in the project's `references/` folder, by the name the
other functions take: the file name without `.csl`.
[`add_journal()`](https://danielsangarci.github.io/easypaper/reference/add_journal.md)
fetches any other journal's style.

## Usage

``` r
list_journals(path = ".")
```

## Arguments

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

A character vector of journal names, sorted.

## See also

[`add_journal()`](https://danielsangarci.github.io/easypaper/reference/add_journal.md),
and the `journal` argument of
[`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md)
and
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md).

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmppAhlbc/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
list_journals(dir)
#> [1] "journal-of-ecology"
unlink(dir, recursive = TRUE)
```
