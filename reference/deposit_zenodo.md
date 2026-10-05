# Reserve the DOI of the data deposit on Zenodo

Uploads the data and code compendium – `data_and_code.zip`, which
[`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
and
[`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
build – to a new Zenodo deposit, fills in its description from the
project, and reserves its DOI, so the manuscript can cite the data
before they are published. It never publishes: the deposit stays a draft
until you review it on Zenodo and press Publish there, which cannot be
undone. Nothing in the package needs it; it runs only when you call it.

## Usage

``` r
deposit_zenodo(file = NULL, sandbox = FALSE, token = NULL, path = ".")
```

## Arguments

- file:

  The compendium to upload. `NULL`, the default, takes the newest
  `data_and_code.zip` in `submission/`.

- sandbox:

  `TRUE` deposits on <https://sandbox.zenodo.org>, to try it.

- token:

  The personal access token. `NULL`, the default, reads `ZENODO_TOKEN`,
  or `ZENODO_SANDBOX_TOKEN` with `sandbox = TRUE`.

- path:

  The project, or any folder inside it. The working directory by
  default, which is the project root once its `.Rproj` is open.

## Value

A list with the deposit's `id`, the reserved `doi` and the `url` of the
draft, invisibly.

## Details

The description comes from the manuscript: the title (the short title,
`short-title:`, when there is one; the title otherwise), the authors
with their affiliations and ORCID (`orcid:` on an author), the keywords,
and the licence of the data, from the project's `LICENSE.txt` (CC BY 4.0
in a new project). The deposit and its DOI are recorded in the
`easypaper:` block of `_quarto.yml`, so a second call – after the data
changed – replaces the file of the same draft instead of opening
another. A deposit already published is left alone: a new version of it
is made on Zenodo.

The DOI is written into the text wherever it says
`10.5281/zenodo.XXXXXXX` – the placeholder of the data availability
statement –, into the cover letters of `submission/` where they say
`[repository DOI]`, and into the project's `README.md`, as a badge and
in its citation; and it is printed, to cite it wherever else it belongs.
A cover letter written after it carries the DOI from the start.

It needs a personal access token of Zenodo, with the scopes
`deposit:write` and `deposit:actions`: create one at
<https://zenodo.org/account/settings/applications/tokens/new/> and put
it in your `.Renviron` as `ZENODO_TOKEN=...`
(`usethis::edit_r_environ()` opens it). To try it first, use Zenodo's
sandbox, a copy of the site for tests: a token from
<https://sandbox.zenodo.org> as `ZENODO_SANDBOX_TOKEN`, and
`sandbox = TRUE`. A sandbox DOI does not resolve, so it is never written
into the text.

## Examples

``` r
if (FALSE) { # \dontrun{
make_submission()            # builds submission/<Journal>/data_and_code.zip
deposit_zenodo(sandbox = TRUE)   # try it on the sandbox first
deposit_zenodo()                 # the real one: a draft, and its DOI
} # }
```
