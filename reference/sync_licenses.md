# Copy the authors into the licences

The authors in the YAML of `manuscript.qmd` are the copyright holders of
the project: this writes them into the copyright line of `LICENSE-CODE`
(MIT) and into the licence notice of `README.md`, between its
`<!-- license:start -->` and `<!-- license:end -->` markers. `LICENSE`
(CC BY 4.0) is the official text and is never touched. Every render does
this on its own; it can be run as many times as you like.

## Usage

``` r
sync_licenses(year = format(Sys.Date(), "%Y"), quiet = FALSE, path = ".")
```

## Arguments

- year:

  The year of the copyright line. This year by default.

- quiet:

  `TRUE` says nothing.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

The holders as written, invisibly.

## See also

[`sync_metadata()`](https://danielsangarci.github.io/easypaper/reference/sync_metadata.md),
which does the same for the data deposit.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, authors = c("Ada Lovelace", "Alan Turing"), git = FALSE)
#> Project created: /tmp/RtmpMgNW60/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
sync_licenses(path = dir)
#> Copyright holders: Ada Lovelace & Alan Turing (2026)
readLines(file.path(dir, "LICENSE-CODE"), n = 3)
#> [1] "MIT License"                                  
#> [2] ""                                             
#> [3] "Copyright (c) 2026 Ada Lovelace & Alan Turing"
unlink(dir, recursive = TRUE)
```
