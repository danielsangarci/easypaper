# Which paper is named

The project
[`set_paper()`](https://danielsangarci.github.io/easypaper/reference/set_paper.md)
named for this session: the one every function works on when it is given
no `path`.

## Usage

``` r
get_paper()
```

## Value

The project's root, or `NULL` when none is named; printed in a sentence
when called from the console, and returned invisibly then.

## See also

[`set_paper()`](https://danielsangarci.github.io/easypaper/reference/set_paper.md)

## Examples

``` r
get_paper()   # NULL: none named yet
#> No project is named. Name it once a session, from its folder: set_paper(".")

dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/Rtmpi6WzmE/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
old <- set_paper(dir)
#> Working on /tmp/Rtmpi6WzmE/my_paper
get_paper()
#> Working on /tmp/Rtmpi6WzmE/my_paper
set_paper(old)
unlink(dir, recursive = TRUE)
```
