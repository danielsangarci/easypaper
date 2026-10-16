# Describe the data deposit by hand

Opens dataspice's editor for one of the four files that describe the
data deposit, in `data/metadata/`: the variables (`"attributes"`: their
description and units), the dataset itself (`"biblio"`: description,
temporal and geographic coverage), the people (`"creators"`) or the
files (`"access"`: the `name` of each is its file name without the
extension, to change if you like). Save in the editor and close it.
[`sync_metadata()`](https://danielsangarci.github.io/easypaper/reference/sync_metadata.md)
has already filled in what the project knows – title, keywords, the
authors with their affiliations, email and ORCID, variable names – so
what is left is what no machine can guess.

## Usage

``` r
edit_metadata(
  what = c("attributes", "biblio", "creators", "access", "write"),
  path = NULL
)
```

## Arguments

- what:

  Which file to edit: `"attributes"` (the default), `"biblio"`,
  `"creators"` or `"access"`; or `"write"` to compile them.

- path:

  The project, or any folder inside it. Left out, the project the
  working directory is in – its root once its `.Rproj` is open – and,
  since this writes into it, in an interactive session the first such
  call asks you to allow it, once a session; in a script, name it.

## Value

The metadata folder, invisibly.

## Details

`what = "write"` opens nothing: it compiles the four files into
`data/metadata/dataspice.json`, the machine-readable description, and
writes `data/metadata/index_metadata.html`, a page to read it. You need
it only to look at them:
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
and
[`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
compile them again before they build the data compendium, which carries
both.

## See also

[`sync_metadata()`](https://danielsangarci.github.io/easypaper/reference/sync_metadata.md),
and <https://docs.ropensci.org/dataspice/> for what each field means.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpaorZQx/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
write.csv(head(iris), file.path(dir, "data", "iris.csv"), row.names = FALSE)

edit_metadata("write", path = dir)   # dataspice.json and its web page
#> Written: /tmp/RtmpaorZQx/my_paper/data/metadata/dataspice.json
#>          /tmp/RtmpaorZQx/my_paper/data/metadata/index_metadata.html
list.files(file.path(dir, "data", "metadata"))
#> [1] "access.csv"          "attributes.csv"      "biblio.csv"         
#> [4] "creators.csv"        "dataspice.json"      "index_metadata.html"

# The editors open in an interactive session.
if (interactive()) {
  edit_metadata("attributes", path = dir)
  edit_metadata("biblio", path = dir)
}
unlink(dir, recursive = TRUE)
```
