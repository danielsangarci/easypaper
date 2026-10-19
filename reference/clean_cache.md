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

  The project, or any folder inside it. Left out, the project the
  working directory is in – its root once its `.Rproj` is open – and,
  since this writes into it, in an interactive session the first such
  call asks you to allow it, once a session; in a script, name it.

## Value

The project's root, invisibly.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpoHtVq9/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
clean_cache(dir)
#> Cache cleared.
unlink(dir, recursive = TRUE)
```
