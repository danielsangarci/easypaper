# easypaper: automate reproducible Quarto manuscripts ready for submission

[`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
writes a project that holds only the paper: the text split into
sections, the references and the journal's citation style, the setup of
the analysis and the data;
[`create_example_paper()`](https://danielsangarci.github.io/easypaper/reference/create_example_paper.md)
writes the same with a small study in it, to see how each part is
written. The functions of the package then build it:

## Details

- render it for any journal:
  [`render_html()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  while you write,
  [`render_docx()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  and
  [`render_pdf()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  for what you send,
  [`render_supplementary()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  for the supplement on its own,
  [`render_all()`](https://danielsangarci.github.io/easypaper/reference/render.md)
  for all of them;

- check it before every render:
  [`check_citations()`](https://danielsangarci.github.io/easypaper/reference/checks.md),
  [`check_crossrefs()`](https://danielsangarci.github.io/easypaper/reference/checks.md),
  [`check_packages()`](https://danielsangarci.github.io/easypaper/reference/checks.md),
  [`check_data()`](https://danielsangarci.github.io/easypaper/reference/checks.md)
  and the rest of
  [checks](https://danielsangarci.github.io/easypaper/reference/checks.md),
  and
  [`check_species()`](https://danielsangarci.github.io/easypaper/reference/check_species.md)
  for the scientific names of the references, and, when you ask,
  [`check_species_text()`](https://danielsangarci.github.io/easypaper/reference/check_species_text.md)
  for those of the text;

- assemble what you send:
  [`make_preprint()`](https://danielsangarci.github.io/easypaper/reference/make_preprint.md)
  for a preprint server, with its data deposit,
  [`deposit_zenodo()`](https://danielsangarci.github.io/easypaper/reference/deposit_zenodo.md)
  to reserve the DOI of the data, and
  [`make_submission()`](https://danielsangarci.github.io/easypaper/reference/make_submission.md)
  for a journal, with the manuscript split for double-blind review and a
  data and code compendium;

- keep it in step:
  [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
  brings data into `data/` in open formats,
  [`sync_metadata()`](https://danielsangarci.github.io/easypaper/reference/sync_metadata.md)
  and
  [`edit_metadata()`](https://danielsangarci.github.io/easypaper/reference/edit_metadata.md)
  describe the data deposit, and
  [`add_journal()`](https://danielsangarci.github.io/easypaper/reference/add_journal.md)
  fetches any journal's citation style.

Every function works on the project the working directory is in – the
project root, once its `.Rproj` is open – or on the one its `path`
argument names.

## Settings

What a project wants done differently is written in the `easypaper:`
block of its `_quarto.yml`, so it travels with the project: whether the
scientific names of the references go in italics (`italicize-species`),
the sections a double-blind submission moves to the title page
(`blinded-sections`), extra open formats for
[`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
(`open-formats`), caption styles of your own (`caption-styles`) and the
Google Drive folder of
[`td_upload()`](https://danielsangarci.github.io/easypaper/reference/trackdown.md)
(`trackdown-folder`).

## See also

[`vignette("easypaper")`](https://danielsangarci.github.io/easypaper/articles/easypaper.md)
for a tour.

## Author

**Maintainer**: Daniel Sanchez-Garcia <danielsangarci@gmail.com>
([ORCID](https://orcid.org/0000-0002-0710-6292)) \[copyright holder\]

Authors:

- Daniel Sanchez-Garcia <danielsangarci@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-0710-6292)) \[copyright holder\]
