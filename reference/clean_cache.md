# Clear the knitr cache

knitr caches each chunk's results and does not notice when a file in
`data/` changes. Run this after changing the data, and the next render
runs every chunk again. It deletes `cache/`, `_freeze/` and `.quarto/`,
which are regenerable and in `.gitignore`.

## Usage

``` r
clean_cache(path = NULL)
```

## Arguments

- path:

  The project, or any folder inside it. Left out, the one
  [`set_paper()`](https://danielsangarci.github.io/easypaper/reference/set_paper.md)
  named; with none named, this stops before writing: it writes into the
  project, and easypaper never takes the working directory for it.

## Value

The project's root, invisibly.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpwQQ5QZ/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
clean_cache(dir)
#> Cache cleared.
unlink(dir, recursive = TRUE)
```
