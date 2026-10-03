# Fill in what the data deposit's metadata can know by itself

The deposit is described by four `.csv` files in `data/metadata/`, in
the format of the dataspice package: `biblio.csv`, `creators.csv`,
`attributes.csv` and `access.csv`. Three of their columns are already
written down elsewhere in the project – the title and the keywords in
the YAML of the manuscript, the authors in the same block, and the
variable names inside the data files – and this copies them across.
Copying them by hand is how a deposit ends up disagreeing with its
paper.

## Usage

``` r
sync_metadata(quiet = FALSE, path = ".")
```

## Arguments

- quiet:

  `TRUE` says nothing.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

What was filled in, as a character vector, invisibly.

## Details

It only ever ADDS. A cell you have filled is never touched and a
variable you have described is never rewritten, so every render runs it
without eating your work. What no machine can guess – units,
descriptions, the temporal and geographic coverage – is yours to write,
with
[`edit_metadata()`](https://danielsangarci.github.io/easypaper/reference/edit_metadata.md).

## See also

[`edit_metadata()`](https://danielsangarci.github.io/easypaper/reference/edit_metadata.md)
for the rest.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, title = "Ant colonies", authors = "Ada Lovelace",
             git = FALSE)
#> Project created: /tmp/RtmpMgNW60/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
write.csv(data.frame(colony = 1:3, richness = c(4, 7, 5)),
          file.path(dir, "data", "colonies.csv"), row.names = FALSE)
sync_metadata(path = dir)
#> Metadata filled in: title, keywords, 1 creator(s), 2 variable(s). The rest is yours: edit_metadata().
read.csv(file.path(dir, "data", "metadata", "attributes.csv"))
#>       fileName variableName description unitText
#> 1 colonies.csv       colony          NA       NA
#> 2 colonies.csv     richness          NA       NA
unlink(dir, recursive = TRUE)
```
