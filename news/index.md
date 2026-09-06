# Changelog

## easypaper 0.1.0

First version.

- [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
  writes the full structure of a reproducible Quarto manuscript:
  sections as separate files, `make.R` as the single entry point,
  journal styles, Word templates, and the folders for data, figures and
  outputs.
- Optional `title` and `authors`, written into the YAML of
  `manuscript.qmd` and into the title page.
- Initialises a git repository and makes the first commit
  (`git = TRUE`), skipping it with a clear message when git is absent or
  has no identity configured.
- The top of the project’s `make.R` records which version of easypaper
  wrote the structure. The project never needs the package again; the
  stamp is what tells you, later, which version produced a project you
  already have.
- Also available from RStudio as **File \> New Project \> New Directory
  \> Reproducible Quarto manuscript**.
