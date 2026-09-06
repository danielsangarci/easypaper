# Getting started with easypaper

A scientific paper is not one document. It is text, analyses, figures,
tables, a bibliography, supplementary material, and — when the time
comes — a blinded manuscript, a title page, figures at the resolution
the journal demands, and a data deposit. easypaper writes that whole
structure in one call, and then gets out of the way.

## Creating a project

``` r

library(easypaper)

create_paper("~/papers/ant_chemistry",
             title   = "Chemical mimicry in Maculinea rebeli",
             authors = c("Daniel Sanchez-Garcia", "Second Author"))
```

In RStudio the same thing is **File \> New Project \> New Directory \>
Reproducible Quarto manuscript**, with fields for the title and the
authors.

The title and the authors are optional; without them the YAML keeps its
placeholders, and `make.R` warns you about them until you replace them.
The affiliation marks are embedded in the names (`First Author^1,\*^`)
because Quarto rebuilds the author line of a `.docx` and drops any
structured affiliation — the affiliations themselves live in
`_sections/0_authors.qmd`.

Here is what lands on disk:

``` r

dir <- file.path(tempdir(), "demo_paper")
easypaper::create_paper(dir, git = FALSE)
#> Project created: /tmp/RtmpuBa6Js/demo_paper
#>   1. open demo_paper.Rproj
#>   2. source("make.R")
#>   3. render_html()      # or see run.R for every command

fs <- list.files(dir, recursive = FALSE, all.files = TRUE, no.. = TRUE)
sort(fs)
#>  [1] "_quarto.yml"       "_sections"         ".gitignore"       
#>  [4] "cache"             "data"              "demo_paper.Rproj" 
#>  [7] "figures"           "format"            "LICENSE"          
#> [10] "LICENSE-CODE"      "make.R"            "manuscript.qmd"   
#> [13] "output"            "R"                 "README.md"        
#> [16] "references"        "references_styles" "run.R"            
#> [19] "supplementary.qmd" "title_page.qmd"
```

``` r

sort(list.files(file.path(dir, "_sections")))
#>  [1] "0_authors.qmd"        "1_abstract.qmd"       "2_introduction.qmd"  
#>  [4] "3_methods.qmd"        "4.1_results1.qmd"     "4.2_results2.qmd"    
#>  [7] "5_discussion.qmd"     "6_figures.qmd"        "7_tables.qmd"        
#> [10] "8_suppl_material.qmd"
```

## The anatomy

`manuscript.qmd` holds no prose. It is a spine: the YAML with title and
authors, and a list of includes in reading order.

    {{< include _sections/2_introduction.qmd >}}
    {{< include _sections/3_methods.qmd >}}
    {{< include _sections/4.1_results1.qmd >}}

The number in front of each file is **the section of the paper**, not a
sequence: Results split in two is `4.1` and `4.2`, exactly as you would
number them in the text. Nothing depends on the alphabetical order of
the files — the build order is the order of those includes, and `make.R`
reads it from there.

Everything else follows one rule: **paths are relative to the project
root**, in the YAML and in the R code alike. `_quarto.yml` sets
`execute-dir: project`, so a chunk runs with the working directory at
the root, and `here::here()` resolves the same way.

## Writing

A typical analysis inside a Results section:

    ```{r}
    #| label: richness-model
    #| cache: true
    richness <- readr::read_csv(here::here("data/processed/richness.csv")) |>
      dplyr::filter(!is.na(S), status != "dead")

    m1 <- glmmTMB::glmmTMB(S ~ treatment + (1 | plot),
                           family = nbinom2, data = richness)
    ```

    Richness was higher in the treatment
    (beta = r round(fixef(m1)$cond[2], 2)), as shown in @fig-richness.

Cleaning happens there, from the input `.csv`, never as a derived file
saved in `data/`. Excluding individuals or recoding a factor is a
scientific decision: it belongs in code a reader can check, not in a
spreadsheet nobody can trace. `#| cache: true` covers the cost of
recomputing it.

## Rendering

``` r

source("make.R")

render_html()                       # seconds, while you write
render_journal("myrmecological-news")   # .docx with that journal's citation style
render_preprint()                   # .pdf
make_all()                          # all of it
```

The journal is an argument, not an edit: it names a `.csl` in
`references_styles/`, and `list_journals()` tells you which ones you
have. Caption style is a second argument — `"default"` gives
`Figure 1.`, `"abbrev"` gives `Fig. 1.`, `"nature"` gives `Figure 1 |`.

`run.R`, inside the project, lists every command with each argument
explained, ready to run one line at a time. It is the file to open when
you cannot remember a name.

## Supplementary material

Two kinds, told apart by what the file contains — nothing to declare:

- **Figures and tables**: any `_sections/8*suppl*.qmd` defining an
  `sfig` or `stbl` div. They are numbered `Figure S1`, `Table S1`, on a
  counter of their own, so a supplementary figure never advances the
  numbering of `Figure 1`.
- **Text** (an extended Methods, say): a supplementary file with no
  floats. It always leaves as its own document, which is the point — its
  reference list is independent from the main text’s.

Where the figures end up is decided when you submit, and the citations
work either way:

``` r

make_submission("myrmecological-news")                        # own document
make_submission("myrmecological-news", suppl_figures = "main") # end of the main text
```

## Submitting

``` r

make_submission("myrmecological-news")                        # -> submission/default/
make_submission("myrmecological-news", label = "MyrmecologicalNews") # the real submission
```

`label` names the folder and every file in it, and defaults to
`"default"`, so a trial run is unmistakably a trial and never carries
the name of a journal you did not choose.

That builds, from what is already in the project:

    submission/default/
      cover_letter_default.docx               template, never overwritten
      CHECKLIST.md                            what still has to be done by hand
      manuscript/
        title_default.docx                    title, authors, affiliations, counts
        main_default.docx                     from the Abstract on, with no names
        supporting_information_*.docx
        figures/Figure_1.tiff ...             600 dpi, renumbered in order
      data_and_code/                          data, metadata, scripts, renv.lock
      data_and_code.zip                       for Zenodo or Dryad

The split into title page and main text is what double-blind review asks
for, and the main text is verified to carry no author name. What is
*not* checked for you — acknowledgements, CRediT, and self-citations of
the kind “in our previous study (Author et al.)” — is listed in the
`CHECKLIST.md`.

The compendium publishes open formats only: the `.csv`, never the source
`.xlsx`, and only the analysis code, not your authoring tooling. Its
`README.txt` is written from what the folder actually holds, so it never
needs editing.

## The checks

Every render runs them, and you can call them yourself:

``` r

check_citations()   # @keys with no entry in references/, and the reverse
check_crossrefs()   # @fig-/@tbl- with no target, and figures nobody cites
check_title()       # has title_page.qmd drifted from the manuscript?
check_renv()        # is renv.lock there, and does it match what you use?
```

The second one has caught more submissions than the rest together: a
figure defined and never cited is a figure the journal will ask you
about.

## Where to read more

The project’s own `README.md` is the reference: the path rule, the
numbering, the known traps, how the two bibliographies stay independent,
and what to do before submitting. It travels inside every project
easypaper creates.
