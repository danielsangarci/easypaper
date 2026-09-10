#' Bring a project's build logic up to the installed easypaper
#'
#' A project carries its own copy of the build logic -- `make.R`, `run.R`,
#' `R/submission.R`, the Word templates, the citation styles -- so it renders
#' with easypaper uninstalled. The price is that a fix in the package does not
#' reach a project already written. This is how it does: the files are
#' refreshed from the installed version, and everything you wrote is left
#' alone.
#'
#' What it touches is an explicit list, not everything the template has:
#' `make.R`, `run.R`, `README.md`, `data/README.md`, `R/submission.R`,
#' `R/crossref_styles.R`, `R/convert_data.R`, `R/renv_setup.R`,
#' `R/create_metadata.R`, the Word templates in `format/` and the `.csl` files
#' the template ships in `references_styles/`. Lines the template's
#' `.gitignore` has and yours lacks are appended; nothing is removed from it.
#'
#' What it never touches: `_sections/`, `manuscript.qmd`, `supplementary.qmd`,
#' `title_page.qmd`, `_quarto.yml`, `references/`, `data/` apart from its
#' README, `R/setup.R`, `R/trackdown.R`, the licences, and any `.csl` you
#' added yourself. Nothing is ever deleted.
#'
#' Two of the managed files are ones you may have edited: `R/convert_data.R`,
#' whose `.cd_open_formats` list is yours to extend, and `make.R`, where a
#' default journal is easy to change. Both are overwritten, and both are
#' accounted for: extensions your copy knew and the new one does not are
#' named so you can put them back, and the project's git history holds the
#' rest. That is why the function insists on a clean working tree: the update
#' is then one commit you can read with `git diff` and revert file by file.
#' In a project with no repository it still runs, and keeps the replaced
#' files in a folder under `tempdir()` until the session ends.
#'
#' `dry_run = TRUE` lists what would change and writes nothing.
#'
#' Some versions also change what is expected of you: 0.2.0 replaced
#' `data/raw/` and `data/csv/` with a single `data/`. Those steps involve your
#' data or your text and are never done for you. They are printed, when the
#' project needs them, as the list of what is left to do by hand.
#'
#' The stamp at the top of `make.R` then records both versions: the one that
#' created the project and the one it was updated to.
#'
#' @param path The project's root, the folder holding `make.R`. The working
#'   directory by default, which is the project root once its `.Rproj` is
#'   open.
#' @param dry_run List the files that would change, and write nothing.
#' @return Invisibly, a data frame with one row per managed file: `file`, and
#'   `action` -- `"update"`, `"add"`, `"append"` (the `.gitignore`) or
#'   `"same"`.
#' @seealso [create_paper()], which writes the project in the first place, and
#'   [add_journal()] for a citation style the template does not ship.
#' @export
#' @examples
#' dir <- file.path(tempdir(), "ant_chemistry")
#' create_paper(dir, git = FALSE)
#' update_project(dir, dry_run = TRUE)   # written by this version: nothing to do
#' unlink(dir, recursive = TRUE)
update_project <- function(path = ".", dry_run = FALSE) {
  .check_string(path, "path")
  .check_flag(dry_run, "dry_run")
  path <- path.expand(path)
  if (!dir.exists(path) || !file.exists(file.path(path, "make.R")) ||
      !file.exists(file.path(path, "_quarto.yml"))) {
    stop("`", path, "` is not an easypaper project: it needs a make.R and a ",
         "_quarto.yml.", call. = FALSE)
  }
  path <- normalizePath(path)
  tpl  <- .template_dir()

  installed <- utils::packageVersion("easypaper")
  stamp     <- .stamp_info(file.path(path, "make.R"))
  written   <- if (is.null(stamp)) NULL else stamp$current
  if (!is.null(written) && written > installed) {
    stop("This project was written by easypaper ", written, " and the ",
         "installed version is ", installed, ": update the package, not the ",
         "project.", call. = FALSE)
  }

  plan    <- .update_plan(path, tpl)
  changes <- plan[plan$action != "same", , drop = FALSE]
  extras  <- setdiff(.open_formats_in(file.path(path, "R", "convert_data.R")),
                     .open_formats_in(file.path(tpl, "R", "convert_data.R")))
  notes   <- .migration_notes(written, path)
  restamp <- is.null(written) || written < installed

  message("Project written by ",
          if (is.null(written)) "an unknown version of easypaper"
          else paste("easypaper", written),
          "; installed: ", installed, ".")
  if (!nrow(changes) && !restamp) {
    message("Every build file already matches: nothing to update.")
    .say_notes(extras, notes)
    return(invisible(plan))
  }
  if (nrow(changes)) {
    message(if (dry_run) "Would write:" else "Writing:", "\n",
            paste(sprintf("  %-7s %s", changes$action, changes$file),
                  collapse = "\n"))
  }
  if (dry_run) {
    .say_notes(extras, notes)
    return(invisible(plan))
  }

  dirty <- .git_dirty(path)
  if (isTRUE(dirty)) {
    stop("The project has uncommitted changes. Commit or stash them first, so ",
         "that this update is one commit you can read with `git diff` and ",
         "revert file by file.", call. = FALSE)
  }
  backup <- .back_up(path, changes$file[changes$action %in% c("update", "append")])

  written_ok <- vapply(changes$file, function(f) {
    if (f == ".gitignore") return(.merge_gitignore(path, tpl, installed))
    dir.create(dirname(file.path(path, f)), recursive = TRUE,
               showWarnings = FALSE)
    file.copy(file.path(tpl, f), file.path(path, f), overwrite = TRUE)
  }, logical(1))
  if (!all(written_ok)) {
    stop("Could not write ", paste(changes$file[!written_ok], collapse = ", "),
         ".", call. = FALSE)
  }
  .make_dirs(path)
  # The stamp was read before make.R was replaced: the fresh copy has none.
  .stamp_version(file.path(path, "make.R"),
                 created = if (is.null(stamp)) NULL else stamp$created)

  message("make.R now records easypaper ", installed, ".")
  if (isFALSE(dirty)) {
    message("Read the result with `git diff`; `git checkout -- <file>` puts ",
            "any one file back.")
  } else if (!is.null(backup)) {
    message("No repository to fall back on: the replaced files are kept in\n  ",
            backup, "\nuntil this R session ends.")
  }
  .say_notes(extras, notes)
  invisible(plan)
}

# --- What is managed -------------------------------------------------------

#' The build files, as an allowlist: what the template has that is logic or
#' documentation of the scaffold, not the manuscript. Relative paths.
#' @noRd
.managed_files <- function(tpl) {
  all <- list.files(tpl, recursive = TRUE)
  exact <- c("make.R", "run.R", "README.md", "data/README.md",
             "R/submission.R", "R/crossref_styles.R", "R/convert_data.R",
             "R/renv_setup.R", "R/create_metadata.R")
  sort(all[all %in% exact |
             grepl("^format/[^/]+[.]docx$|^references_styles/[^/]+[.]csl$", all)])
}

#' One row per managed file and what would happen to it.
#' @noRd
.update_plan <- function(path, tpl) {
  files <- .managed_files(tpl)
  action <- vapply(files, function(f) {
    mine   <- file.path(path, f)
    theirs <- file.path(tpl, f)
    if (!file.exists(mine)) return("add")
    same <- if (f == "make.R") {
      # The stamp is the one line that is supposed to differ.
      identical(.strip_stamp(readLines(mine, warn = FALSE)),
                .strip_stamp(readLines(theirs, warn = FALSE)))
    } else {
      unname(tools::md5sum(mine)) == unname(tools::md5sum(theirs))
    }
    if (isTRUE(same)) "same" else "update"
  }, character(1), USE.NAMES = FALSE)
  gitignore <- if (!file.exists(file.path(path, ".gitignore"))) "add"
               else if (length(.gitignore_missing(path, tpl))) "append"
               else "same"
  data.frame(file = c(files, ".gitignore"), action = c(action, gitignore),
             stringsAsFactors = FALSE)
}

#' The rules of the template's .gitignore that the project's lacks. Comments
#' and blank lines are not rules.
#' @noRd
.gitignore_missing <- function(path, tpl) {
  rules <- function(f) {
    x <- trimws(readLines(f, warn = FALSE))
    x[nzchar(x) & !startsWith(x, "#")]
  }
  mine <- file.path(path, ".gitignore")
  theirs <- rules(file.path(tpl, "gitignore"))
  if (!file.exists(mine)) theirs else setdiff(theirs, rules(mine))
}

#' Add the missing rules at the end, under a dated heading. Never removes.
#' @noRd
.merge_gitignore <- function(path, tpl, version) {
  mine <- file.path(path, ".gitignore")
  if (!file.exists(mine)) {
    return(file.copy(file.path(tpl, "gitignore"), mine))
  }
  missing <- .gitignore_missing(path, tpl)
  if (!length(missing)) return(TRUE)
  writeLines(c(readLines(mine, warn = FALSE), "",
               paste0("# Added by easypaper ", version), missing), mine)
  TRUE
}

# --- Safety nets -----------------------------------------------------------

#' TRUE when the project's repository has uncommitted changes, FALSE when it
#' is clean, NA when there is no repository or no git to ask.
#' @noRd
.git_dirty <- function(path) {
  if (!dir.exists(file.path(path, ".git")) || !nzchar(Sys.which("git"))) {
    return(NA)
  }
  st <- .git(c("status", "--porcelain"), dir = path)
  if (!st$ok) return(NA)
  length(st$out) > 0L
}

#' Copy the files about to be replaced under tempdir(), keeping their relative
#' paths. Returns the folder, or NULL when there was nothing to keep.
#' @noRd
.back_up <- function(path, files) {
  files <- files[file.exists(file.path(path, files))]
  if (!length(files)) return(NULL)
  dest <- file.path(tempdir(),
                    paste0("easypaper_backup_", format(Sys.time(), "%Y%m%d_%H%M%S")))
  ok <- vapply(files, function(f) {
    dir.create(dirname(file.path(dest, f)), recursive = TRUE,
               showWarnings = FALSE)
    file.copy(file.path(path, f), file.path(dest, f), overwrite = TRUE)
  }, logical(1))
  if (all(ok)) dest else NULL
}

# --- What the update cannot do for you -------------------------------------

#' The `.cd_open_formats` a convert_data.R declares, or nothing. Parsed, not
#' sourced: only that one assignment is evaluated, in an empty environment.
#' @noRd
.open_formats_in <- function(f) {
  if (!file.exists(f)) return(character(0))
  exprs <- tryCatch(parse(f, keep.source = FALSE), error = function(e) NULL)
  for (e in as.list(exprs)) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) &&
        identical(e[[2]], as.name(".cd_open_formats"))) {
      v <- tryCatch(eval(e[[3]], new.env(parent = baseenv())),
                    error = function(err) NULL)
      return(if (is.character(v)) tolower(v) else character(0))
    }
  }
  character(0)
}

#' The steps a version leaves to the author, taken from NEWS.md, for the
#' versions between the one that wrote the project and the one installed.
#' Only the ones this project actually needs.
#' @noRd
.migration_notes <- function(written, path) {
  notes <- character(0)
  if (is.null(written) || written < "0.2.0") {
    old <- c("data/raw", "data/csv")
    old <- old[dir.exists(file.path(path, old))]
    if (length(old)) {
      notes <- c(notes, paste0(
        "0.2.0 replaced data/raw/ and data/csv/ with a single data/, and this ",
        "project still has ", paste0(old, "/", collapse = " and "), ". Move ",
        "the contents of data/csv/ up into data/ and delete the empty folder; ",
        "move data/raw/ wherever your originals should live, inside the ",
        "project or outside it; and change the paths the analysis reads from ",
        "data/csv/... to data/..."))
    }
    if (file.exists(file.path(path, "R", "xlsx_to_csv.R"))) {
      notes <- c(notes, paste0(
        "0.2.0 replaced R/xlsx_to_csv.R with R/convert_data.R. The old file ",
        "is left where it is; delete it once nothing of yours sources it."))
    }
  }
  # Not keyed on a version: what matters is whether the folders are there.
  old_out <- file.path("output", c("journal", "preprint", "supplementary"))
  old_out <- old_out[dir.exists(file.path(path, old_out))]
  if (length(old_out)) {
    notes <- c(notes, paste0(
      "A render now writes straight into output/, with no subfolder, and ",
      "this project still has ", paste0(old_out, "/", collapse = ", "),
      ". Whatever is in them is a stale copy: everything under output/ is ",
      "regenerable, so delete the folder and render again."))
  }
  notes
}

#' @noRd
.say_notes <- function(extras, notes) {
  if (length(extras)) {
    message("Your copy of R/convert_data.R listed ",
            paste(extras, collapse = ", "), " as open formats and the new one ",
            "does not. Put them back at the top of the file, or pass also = c(",
            paste0('"', extras, '"', collapse = ", "),
            ") when you call convert_data().")
  }
  if (length(notes)) {
    message("To do by hand:\n", paste0("  * ", notes, collapse = "\n"))
  }
  invisible(NULL)
}
