# Check the scientific names in the text

Reads the manuscript – every section, the captions of the figures and
tables, the supplement – and reports, with the file and the line, every
scientific name not written the way journals ask.

## Usage

``` r
check_species_text(
  authority = TRUE,
  abbreviate = TRUE,
  exclude = NULL,
  quiet = FALSE,
  path = "."
)
```

## Arguments

- authority:

  `TRUE` (the default) asks for the authority at the first mention of
  each species in the main text. `FALSE` for a journal that does not
  want it, or gives the authorities in a table.

- abbreviate:

  `TRUE` (the default) asks for the genus abbreviated after the first
  mention. `FALSE` for a journal that writes names in full every time.

- exclude:

  Pairs of words that look like a name and are not one, or names to
  leave alone: `"Pinus pinea"`.

- quiet:

  `TRUE` returns what it found without printing it.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

A data frame, invisibly when printed, with one row per thing to look at:
`file`, `line`, `name` as it is written, `problem`, and `fix`, what to
write instead. The species found are its `species` attribute.

## Details

What they ask for:

- **In italics**, the genus and the epithet, abbreviated or not, and a
  genus on its own (*Formica*); `sp.` and `spp.` in roman (*Formica*
  spp.).

- **In full the first time** (*Formica rufa*), and abbreviated after
  that (*F. rufa*) – except at the start of a sentence, which never
  opens with an abbreviation, and when two genera of the text share the
  initial (*Formica*, *Fagus*), where *F.* would not say which. Headings
  and captions, which are read on their own, may give the name in full.

- **With its authority the first time** in the main text: *Formica rufa*
  Linnaeus, 1761, or (Linnaeus, 1761) for a species moved to another
  genus. The authority GBIF gives is suggested.

The abstract, the main text and the supplement are read as three
documents, as a reader meets them: a name is given in full at its first
mention in each. The title is only checked for italics.

Nothing is changed: whether a name in full there is a slip or a choice –
a sentence that compares two species of the same genus – is yours to
say. Nothing calls it either: it runs when you call it, never in a
render.

## How names are recognised

A pair of words shaped like a genus and an epithet is a name when GBIF
lists the species, or – when it is in italics somewhere in the text –
its genus and its epithet. An abbreviation (*F. rufa*) is a name when it
abbreviates one of those, or GBIF knows its epithet. What GBIF said is
kept in `references/species_cache.rds`, the cache of
[`check_species()`](https://danielsangarci.github.io/easypaper/reference/check_species.md),
so only new names need a connection. Without one, the cache answers, a
pair already in italics is taken for a name, and a warning says what
could not be checked.

## See also

[`check_species()`](https://danielsangarci.github.io/easypaper/reference/check_species.md),
for the names in the reference list.

## Examples

``` r
dir <- file.path(tempdir(), "my_paper")
create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpyulCis/my_paper
#>   1. open my_paper.Rproj
#>   2. library(easypaper)
#>   3. render_html()      # see ?render for every command
writeLines(c("Colonies of Formica rufa were sampled.", "",
             "*Formica rufa* builds mounds."),
           file.path(dir, "_sections", "02_introduction.qmd"))
# Offline: only the cache answers, and the pair in italics is taken for a
# name. Online, GBIF is asked once for each new name.
old <- options(easypaper.species_offline = TRUE)
suppressWarnings(check_species_text(path = dir))
#> Scientific names in the text: Formica rufa
#> 2 things to look at:
#>   _sections/02_introduction.qmd:1  Formica rufa  not in italics -> *Formica rufa*
#>   _sections/02_introduction.qmd:1  Formica rufa  first mention without its authority -> Formica rufa Author, year
options(old)
unlink(dir, recursive = TRUE)
```
