# Name the paper to work on

The functions that write into a project – the renders, the submissions,
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
and the rest – write into the one you name: here, once a session, or
with `path` in each call. easypaper never takes the working directory
for it: with neither, a function that writes stops before writing
anything. The functions that only read, such as
[`check_citations()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
or
[`manuscript_stats()`](https://danielsangarci.github.io/easypaper/reference/manuscript_stats.md),
use the project named here too, and otherwise the one the working
directory is in.

## Usage

``` r
set_paper(path)
```

## Arguments

- path:

  The project, or any folder inside it: `"."` from the project's folder.
  `NULL` forgets the one named, and then nothing is written until a
  project is named again.

## Value

The project named before, invisibly – `NULL` if none was – so that it
can be put back.

## Details

Once the project's `.Rproj` is open, the working directory is its root,
so `set_paper(".")` names it. The project stays named until the session
ends or you name another; `path` in a call works on that project for
that call alone.

## See also

[`get_paper()`](https://danielsangarci.github.io/easypaper/reference/get_paper.md),
which says which project is named, and
[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md),
which makes one.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpFXzpSf/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
old <- set_paper(dir)
#> Working on /tmp/RtmpFXzpSf/my_paper
get_paper()
#> Working on /tmp/RtmpFXzpSf/my_paper
list_journals()
#> [1] "journal-of-ecology"
set_paper(old)
unlink(dir, recursive = TRUE)
```
