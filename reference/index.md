# Package index

## Creating a project

The one function you need.

- [`create_paper()`](https://danielsangarci.github.io/easypaper/reference/create_paper.md)
  : Create a reproducible Quarto manuscript project

## Bringing your data in

Originals live wherever you keep them; data/ is the folder that
publishes. This brings a copy in, converted or copied, in a format that
will still open in twenty years. create_paper() writes the same function
into every project, so it works with easypaper uninstalled.

- [`convert_data()`](https://danielsangarci.github.io/easypaper/reference/convert_data.md)
  : Convert or copy originals into the project's data folder

## Adding a journal

Any journal’s citation style, fetched from the official CSL repository
into references_styles/, where render_docx(“”) looks for it.

- [`add_journal()`](https://danielsangarci.github.io/easypaper/reference/add_journal.md)
  : Add a journal's citation style to the project

## Keeping a project current

A project carries its own copy of the build logic. This refreshes it
from the installed easypaper and touches nothing you wrote.

- [`update_project()`](https://danielsangarci.github.io/easypaper/reference/update_project.md)
  : Bring a project's build logic up to the installed easypaper

## Package

- [`easypaper`](https://danielsangarci.github.io/easypaper/reference/easypaper-package.md)
  [`easypaper-package`](https://danielsangarci.github.io/easypaper/reference/easypaper-package.md)
  : easypaper: scaffold a reproducible Quarto manuscript
