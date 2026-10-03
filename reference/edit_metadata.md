# Describe the data deposit by hand

Opens dataspice's editor for one of the four files that describe the
data deposit, in `data/metadata/`: the variables (`"attributes"`: their
description and units), the dataset itself (`"biblio"`: description,
temporal and geographic coverage), the people (`"creators"`:
affiliations, ORCID) or the files (`"access"`). Save in the editor and
close it.
[`sync_metadata()`](https://danielsangarci.github.io/easypaper/reference/sync_metadata.md)
has already filled in what the project knows – title, keywords, authors,
variable names – so what is left is what no machine can guess.

## Usage

``` r
edit_metadata(
  what = c("attributes", "biblio", "creators", "access", "write"),
  path = "."
)
```

## Arguments

- what:

  Which file to edit: `"attributes"` (the default), `"biblio"`,
  `"creators"` or `"access"`; or `"write"` to compile them.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

The metadata folder, invisibly.

## Details

`what = "write"` opens nothing: it compiles the four files into
`data/metadata/dataspice.json`, the machine-readable description, and
writes `data/metadata/index_metadata.html`, a page to read it. The data
compendium of
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
carries both.

## See also

[`sync_metadata()`](https://danielsangarci.github.io/easypaper/reference/sync_metadata.md),
and <https://docs.ropensci.org/dataspice/> for what each field means.

## Examples

``` r
if (FALSE) { # \dontrun{
# Inside a project, with its .Rproj open. The editors are interactive.
edit_metadata("attributes")   # units and descriptions of every variable
edit_metadata("biblio")       # what the dataset is, when and where
edit_metadata("write")        # dataspice.json and its web page
} # }
```
