#' easypaper: automate reproducible Quarto manuscripts from draft to submission
#'
#' [create_paper()] writes a project that holds only the paper: the text split
#' into sections, the references and the journal's citation style, the setup
#' of the analysis and the data; [create_example_paper()] writes the same with
#' a small study in it, to see how each part is written. The functions of the
#' package then build it:
#'
#' * render it for any journal: [render_html()] while you write,
#'   [render_docx()] and [render_pdf()] for what you send,
#'   [render_supplementary()] for the supplement on its own, [render_all()] for
#'   all of them;
#' * check it before every render: [check_citations()], [check_crossrefs()],
#'   [check_packages()], [check_data()] and the rest of [checks], and
#'   [check_species()] for the scientific names of the references, and, when
#'   you ask, [check_species_text()] for those of the text;
#' * assemble what you send: [make_preprint()] for a preprint server, with
#'   its data deposit, [deposit_zenodo()] to reserve the DOI of the data, and
#'   [make_submission()] for a journal, with the manuscript split for
#'   double-blind review and a data and code compendium;
#' * keep it in step: [convert_data()] brings data into `data/` in open
#'   formats, [sync_metadata()] and [edit_metadata()] describe the data
#'   deposit, and [add_journal()] fetches any journal's citation style.
#'
#' Every function works on the project the working directory is in -- the
#' project root, once its `.Rproj` is open -- or on the one its `path`
#' argument names.
#'
#' @section Settings:
#' What a project wants done differently is written in the `easypaper:` block
#' of its `_quarto.yml`, so it travels with the project: whether the
#' scientific names of the references go in italics (`italicize-species`), the
#' sections a double-blind submission moves to the title page
#' (`blinded-sections`), extra open formats for [convert_data()]
#' (`open-formats`), caption styles of your own (`caption-styles`) and the
#' Google Drive folder of [td_upload()] (`trackdown-folder`).
#'
#' @seealso `vignette("easypaper")` for a tour.
#' @keywords internal
"_PACKAGE"
