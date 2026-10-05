# Set the scientific names of a bibliography in italics

Reference lists come out of Quarto and R Markdown with genus and species
names in roman, because citeproc cannot tell a scientific name from any
other word. This rewrites a bibliography so that it can: every genus,
species, abbreviation (*Q. suber*) and subspecies in the titles is
found, checked against the GBIF Backbone Taxonomy, and marked in italics
in a copy of the bibliography that you then hand to Quarto or R Markdown
instead of the original. The original is only ever read.

## Usage

``` r
italicize_species(
  input,
  output = NULL,
  names = NULL,
  exclude = NULL,
  gbif = TRUE,
  keep_case = TRUE,
  protect = NULL,
  cache = .sp_default_cache(),
  fields = c("title", "title-short", "container-title", "collection-title",
    "original-title"),
  quiet = FALSE
)
```

## Arguments

- input:

  The bibliography to read: a `.bib` (BibTeX or BibLaTeX) or a `.json`
  (CSL-JSON, as Zotero exports it).

- output:

  The CSL-JSON file to write, which is the one the document must name in
  `bibliography:`. By default beside `input`, ending in `_italic.json`.

- names:

  Names to set in italics whatever GBIF says, for the rare one it does
  not know: a species ("Pinus halepensis"), an abbreviation ("Q. ruber")
  or a genus on its own ("Quercus"). Rarely needed.

- exclude:

  Names found that must stay in roman.

- gbif:

  `FALSE` looks nothing up, and only `names` is set in italics.

- keep_case:

  `TRUE`, the default, keeps every title exactly as the bibliography
  writes it, whatever the style. `FALSE` lets pandoc and the style
  change it the way they normally would: pandoc lowercases the titles of
  a `.bib`, a style like Chicago capitalises every word. Use `protect`
  then for the words that must keep their form. Scientific names keep
  theirs either way.

- protect:

  Words or phrases whose capitals are kept in any style: "Spain",
  "Mediterranean", "DNA".

- cache:

  The `.rds` file where the answers of GBIF and Wikipedia are kept, or
  `NULL` to keep none. By default one file in the user's cache directory
  ([`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)),
  shared by every bibliography.

- fields:

  The CSL fields of each reference to look into. A `container-title` is
  only read when it is a book's, the one a chapter belongs to: a
  journal's name is never touched.

- quiet:

  `TRUE` says nothing, except when there was no connection: that warning
  is always raised, because the result may then be incomplete.

## Value

The path of `output`, invisibly, with three attributes: `italicized`,
the names set in italics; `doubtful`, a data frame of the cases left for
you to decide (`id`, `word`, `reason`, `line`); and `offline`, `TRUE`
when something could not be looked up.

## Details

Inside an easypaper project there is nothing to call: every `render_*()`
runs this on the project's bibliography first. This is the same
function, for a bibliography anywhere else. Point the document at the
file it writes:

    bibliography: references_italic.json

    # first chunk of the .qmd or .Rmd: it runs before pandoc reads the file
    easypaper::italicize_species("references.bib", "references_italic.json")

## How names are found

Nothing has to be listed by hand. Anything in a title shaped like a
scientific name is looked up in GBIF, and in the English Wikipedia where
a word could also be something else:

- **Genus and epithet** ("Quercus suber"): the species exists in GBIF,
  or its genus and its epithet both do – so a combination GBIF lacks
  still counts. An epithet written in capitals ("Helicobacter Pylori")
  is lowercased.

- **New species** ("Haemoproteus trarotraro n. sp."): a known genus
  followed by `n. sp.`, `sp. nov.` or `comb. nov.`.

- **Abbreviations** ("Q. suber"): the epithet exists in GBIF; the genus
  need not be spelled out anywhere.

- **Subspecies and varieties** ("Quercus ilex subsp. ballota",
  "Epilachna sparsa orientalis"): the infraspecific epithet in italics,
  the rank (`subsp.`, `var.`, `f.`) in roman.

- **A genus on its own** ("Wolbachia infections", "Quercus spp."): it
  appears in a binomial elsewhere in the bibliography, is followed by
  `sp.`, `spp.` or `species` or preceded by "genus", or Wikipedia
  describes it as a genus. That last check is what keeps "China",
  "Andes" and "America" – all animal genera in GBIF – in roman.

- **A genus that is also an English common name** (gorilla, bison, lynx,
  eucalyptus, according to GBIF's vernacular names): only in italics
  where the capital says it is the genus, halfway through a
  sentence-case title ("Seasonal diet of Gorilla in Gabon"). At the
  start of a title, or in a title-case one ("Gorilla Conservation in
  Africa"), the capital says nothing and the word is read as the common
  name.

Higher taxa, virus names, genes and Latin phrases (*in vitro*) are left
alone: they are not genera or species.

## Doubtful cases

When a word could be a genus and the title cannot tell – a common name
in a position that says nothing, a word Wikipedia gives several meanings
("Iris", "Rosa"), a binomial GBIF does not list – it is left in roman
and reported, with the line of the file it is on and what to write
there. The mark is made in the bibliography itself and affects that
reference only:

- in a `.bib`: `\textit{Gorilla}` (or `\emph{}`) for italics,
  `\textup{Gorilla}` (or `\textrm{}`, `\textnormal{}`) for roman;

- in CSL-JSON: `<i>Gorilla</i>` and
  `<span style="font-style:normal;">Gorilla</span>`.

A marked word is not reported again.

## The cache, and working offline

Every answer from GBIF and Wikipedia is kept in `cache`, so only a name
never seen before needs a connection: the first run over a hundred new
references takes a couple of minutes, the next ones a fraction of a
second. Without a connection nothing fails: the cache is used, whatever
could not be checked is left in roman, and a warning says so. What could
not be checked is not written to the cache, so running again online
completes it. `options(easypaper.species_offline = TRUE)` works that way
on purpose, with a connection or without: nothing is looked up, and only
the cache answers.

The cache is small, about 5 KB per hundred references. Kept in git
beside the bibliography, it makes the result the same on every computer,
with or without a connection, and years later however GBIF and Wikipedia
change. That is where an easypaper project keeps it:
`references/species_cache.rds`.

## See also

[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md),
whose projects run this before every render.

## Examples

``` r
# A CSL-JSON bibliography, as Zotero exports it. With gbif = FALSE nothing
# is looked up, and only the names given are set in italics.
refs <- file.path(tempdir(), "refs.json")
writeLines('[{"id": "perez2020", "type": "article-journal",
  "title": "Effects of fire on Pinus halepensis regeneration"}]', refs)
out <- italicize_species(refs, names = "Pinus halepensis", gbif = FALSE)
#> Scientific names in italics (1): Pinus halepensis
#> Written: /tmp/RtmpXrpJXp/refs_italic.json
jsonlite::read_json(out)[[1]]$title
#> [1] "<span class=\"nocase\">Effects of fire on <i><span class=\"nocase\">Pinus halepensis</span></i> regeneration</span>"
unlink(c(refs, out))

# The real thing: a .bib, every name looked up in GBIF. Needs pandoc (it
# comes with Quarto and RStudio) and, the first time, a connection:
#   italicize_species("references.bib", "references_italic.json")
```
