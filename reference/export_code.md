# Write the analysis code as one script

Extracts the R code of `R/setup.R` and of every section, in the order
the manuscript includes them, into `output/analysis_code.R`, with a
header per section. It opens with a table of contents: the line each
section starts on, and the labels of its chunks, so each analysis is
found at a glance – the richness model in Results, part 1, say. Beside
it goes `output/sessionInfo.txt`, with the versions of R, of every
package and of Quarto, and a copy of `renv.lock` when there is one.
[`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md)
and
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
run it on their own; the submission compendium carries what it writes.

## Usage

``` r
export_code(path = NULL)
```

## Arguments

- path:

  The project, or any folder inside it. Left out, the one
  [`set_paper()`](https://danielsangarci.github.io/easypaper/reference/set_paper.md)
  named; with none named, this stops before writing: it writes into the
  project, and easypaper never takes the working directory for it.

## Value

The path of `analysis_code.R`, invisibly.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpwQQ5QZ/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
export_code(dir)
#> Written: /tmp/RtmpwQQ5QZ/my_paper/output/analysis_code.R
list.files(file.path(dir, "output"))
#> [1] "analysis_code.R" "sessionInfo.txt"
unlink(dir, recursive = TRUE)
```
