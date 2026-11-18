# Which scientific names of the references go in italics

Every render sets the genera and species in the titles of the reference
list in italics, and says – once per session – which cases it could not
settle and what to write in the `.bib` to settle them. This says it
again, without rendering. How the names are found is in
[`italicize_species()`](https://danielsangarci.github.io/easypaper/reference/italicize_species.md).

## Usage

``` r
check_species(path = NULL)
```

## Arguments

- path:

  The project, or any folder inside it. Left out, the one
  [`set_paper()`](https://danielsangarci.github.io/easypaper/reference/set_paper.md)
  named; with none named, this stops before writing: it writes into the
  project, and easypaper never takes the working directory for it.

## Value

The bibliography files a render would hand Quarto, invisibly.

## Details

Unlike the checks of
[checks](https://danielsangarci.github.io/easypaper/reference/checks.md),
which only read, this writes: what GBIF and Wikipedia said about each
name it looks up is kept in `references/species_cache.rds`. Commit it:
with it every computer renders the same italics, offline, years from
now. Delete it to have every name looked up again.
`italicize-species: false` in the `easypaper:` block of `_quarto.yml`
turns the italics off.

## See also

[`italicize_species()`](https://danielsangarci.github.io/easypaper/reference/italicize_species.md),
the same for any bibliography outside a project.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpHi6qdT/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. set_paper(".")      # the project to work on, once a session
#>   4. render_html()      # see ?render for every command
# Offline: only the cache answers, and a name it does not know stays in
# roman, with a warning. Online, a render looks each new name up once.
old <- options(easypaper.species_offline = TRUE)
if (rmarkdown::pandoc_available()) try(check_species(dir))
#> Scientific names in italics (2): Maculinea rebeli, Myrmica
options(old)
unlink(dir, recursive = TRUE)
```
