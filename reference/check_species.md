# Which scientific names of the references go in italics

Every render sets the genera and species in the titles of the reference
list in italics, and says – once per session – which cases it could not
settle and what to write in the `.bib` to settle them. This says it
again, without rendering. How the names are found is in
[`italicize_species()`](https://danielsangarci.github.io/easypaper/reference/italicize_species.md).

## Usage

``` r
check_species(path = ".")
```

## Arguments

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

The bibliography files a render would hand Quarto, invisibly.

## Details

What GBIF and Wikipedia said about each name is kept in
`references/species_cache.rds`. Commit it: with it every computer
renders the same italics, offline, years from now. Delete it to have
every name looked up again. `italicize-species: false` in the
`easypaper:` block of `_quarto.yml` turns the italics off.

## See also

[`italicize_species()`](https://danielsangarci.github.io/easypaper/reference/italicize_species.md),
the same for any bibliography outside a project.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpMgNW60/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
# Offline: only the cache answers, and a name it does not know stays in
# roman, with a warning. Online, a render looks each new name up once.
old <- options(easypaper.species_offline = TRUE)
if (rmarkdown::pandoc_available()) try(check_species(dir))
#> Looking up 3 new name(s) in GBIF...
#> Warning: No connection to GBIF/Wikipedia: 6 candidate words could not be checked, so this version may be missing italics. Run again with a connection; what has been checked stays in the cache (species_cache.rds).
#> No scientific names found in references.bib (none could be checked without a connection)
options(old)
unlink(dir, recursive = TRUE)
```
