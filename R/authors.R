# The title block: the authors on one line, with the marks of their
# affiliations, and the affiliations themselves under it.
#
# The authors are written the way Quarto documents them -- `affiliations:` on
# each author, pointing at the list of affiliations below -- and the package
# works out the marks. Quarto itself cannot: in a .docx it prints the names
# alone, with no affiliation and no asterisk. So every render of the package
# hands Quarto the names as one line, marks included, and the affiliations()
# chunk of manuscript.qmd writes the affiliations under it.

#' The name of one author of the YAML: a string, `name:`, or the parts Quarto
#' also accepts -- `literal:`, or `given:` and `family:`.
#' @noRd
.person_name <- function(x) {
  if (is.character(x)) return(x[1])
  if (!is.list(x)) return(NULL)
  n <- x[["name"]]
  if (is.character(n)) return(n[1])
  if (is.list(n)) {
    if (is.character(n$literal)) return(n$literal[1])
    parts <- unlist(n[intersect(c("given", "dropping-particle",
                                  "non-dropping-particle", "family"),
                                names(n))])
    if (length(parts)) return(paste(parts, collapse = " "))
  }
  NULL
}

#' The authors of the YAML as a list of one element per author, however it
#' wrote them: `author: [Ada, Alan]` reaches R as a vector, one author
#' written as a map as a named list.
#' @noRd
.author_list <- function(own) {
  a <- own$author
  if (is.null(a)) return(list())
  if (is.character(a)) return(as.list(a))
  if (!is.list(a) || !is.null(names(a))) return(list(a))
  a
}

#' One affiliation as the paper prints it: the fields Quarto knows, in the
#' order an address runs, or the one line of `address:` -- or `name:` -- that
#' says it all.
#' @noRd
.affiliation_text <- function(a) {
  if (!is.list(a)) {
    a <- trimws(as.character(a)[1])
    return(if (is.na(a) || !nzchar(a)) NA_character_ else a)
  }
  fields <- c("department", "name", "address", "city", "region", "state",
              "postal-code", "country")
  parts <- unlist(lapply(fields, function(f) {
    v <- a[[f]]
    if (is.character(v) && nzchar(trimws(v[1]))) trimws(v[1])
  }))
  if (length(parts)) paste(parts, collapse = ", ") else NA_character_
}

#' The title block of a manuscript: the line of names with their marks, and
#' the lines that go under it.
#'
#' The affiliations are numbered in the order the authors first name them, so
#' reordering the authors renumbers them. An affiliation named by an author is
#' an `id:` of the list of affiliations; with no list, the name itself. An id
#' that is not in the list stops the render: it is a typo, and printing it as
#' an affiliation would send it to the journal.
#' @noRd
.title_block <- function(own) {
  authors <- own$author
  # `author: [Ada, Alan]` reaches here as a vector, one author written as a
  # map as a named list.
  if (is.null(authors)) authors <- list()
  if (is.character(authors)) authors <- as.list(authors)
  if (!is.null(names(authors))) authors <- list(authors)
  pool <- own$affiliations
  if (!is.null(pool) && (!is.list(pool) || !is.null(names(pool)))) {
    pool <- list(pool)
  }
  ids <- vapply(pool, function(p) {
    if (is.list(p) && !is.null(p$id)) as.character(p$id)[1] else NA_character_
  }, character(1))

  texts <- character(0)             # the affiliations, numbered by position
  number <- function(key, text) {
    k <- match(key, names(texts))
    if (is.na(k)) {
      texts[[key]] <<- text
      k <- length(texts)
    }
    k
  }
  names_ <- character(0)
  orcids <- character(0)
  emails <- character(0)
  for (x in authors) {
    n <- .person_name(x)
    if (is.null(n) || !nzchar(trimws(n))) next
    refs <- NULL
    if (is.list(x)) {
      refs <- x[["affiliations"]]
      if (is.null(refs)) refs <- x[["affiliation"]]
    }
    # [a, b] reaches here as a vector, one affiliation written as a map as a
    # named list, and a list of them as a list.
    if (is.list(refs) && !is.null(names(refs))) {
      refs <- list(refs)
    } else if (!is.list(refs)) {
      refs <- as.list(refs)
    }
    nums <- integer(0)
    for (r in refs) {
      id <- if (is.list(r) && !is.null(r$ref)) as.character(r$ref)[1]
            else if (is.character(r) || is.numeric(r)) as.character(r)[1]
      if (!is.null(id) && (id %in% ids || length(pool))) {
        k <- match(id, ids)
        if (is.na(k)) {
          stop("The author ", n, " names the affiliation `", id, "`, which ",
               "is not an id of the `affiliations:` of manuscript.qmd. The ",
               "ids there: ", paste(ids[!is.na(ids)], collapse = ", "), ".",
               call. = FALSE)
        }
        text <- .affiliation_text(pool[[k]])
        if (is.na(text)) {
          stop("The affiliation `", id, "` of manuscript.qmd is empty: ",
               "write it in its `address:`.",
               call. = FALSE)
        }
        nums <- c(nums, number(paste0("id:", id), text))
      } else {
        text <- .affiliation_text(r)
        if (is.na(text)) next
        nums <- c(nums, number(paste0("text:", text), text))
      }
    }
    corresponding <- is.list(x) && isTRUE(x[["corresponding"]])
    if (corresponding && is.character(x[["email"]])) {
      emails <- c(emails, x[["email"]][1])
    }
    marks <- c(as.character(unique(nums)), if (corresponding) "\\*")
    names_ <- c(names_, paste0(trimws(n), if (length(marks))
      paste0("^", paste(marks, collapse = ","), "^")))
    o <- if (is.list(x) && is.character(x[["orcid"]])) trimws(x[["orcid"]][1]) else ""
    orcids <- c(orcids, sub("^https?://orcid\\.org/", "", o))
  }
  lines <- if (length(texts)) paste0("^", seq_along(texts), "^ ", texts)
  if (length(emails)) {
    lines <- c(lines, paste0("^\\*^ Correspondence: ",
                             paste(emails, collapse = ", ")))
  }
  unused <- setdiff(ids[!is.na(ids)],
                    sub("^id:", "", grep("^id:", names(texts), value = TRUE)))
  list(line = if (length(names_)) paste(names_, collapse = ", "),
       lines = lines, unused = unused,
       # One by one, for what lays them out its own way (the README).
       people = names_, orcid = orcids)
}

#' What a render hands Quarto as `author:`: the authors as a paper prints
#' them, one line, "Ada^1,\\*^, Alan^2^". Quarto gives each author of a list
#' a paragraph of its own, so a render handed the list stacks them one under
#' another; one name holding them all comes out on one line, marks included.
#' manuscript.qmd keeps its list, which is what .author_names() and the
#' metadata read. NULL when there are no authors.
#' @noRd
.render_author <- function(own) {
  .title_block(own)$line
}

#' Every render reads the title block before it starts: a typo in an
#' affiliation id stops it here, and an affiliation no author names, or one
#' still from the template, gets a warning.
#' @noRd
.check_authors <- function() {
  tb <- .title_block(rmarkdown::yaml_front_matter(.master()))
  if (length(tb$unused)) {
    warning("No author of manuscript.qmd names the affiliation ",
            paste0("`", tb$unused, "`", collapse = ", "), ": it is left out.",
            call. = FALSE, immediate. = TRUE)
  }
  left <- grep("^\\^[0-9]+\\^ Institution [0-9]+,", tb$lines, value = TRUE)
  if (length(left)) {
    warning("manuscript.qmd still has the template's affiliations (",
            paste(sub("^\\^[0-9]+\\^ ", "", left), collapse = "; "),
            "). Replace them with the real ones.", call. = FALSE,
            immediate. = TRUE)
  }
  invisible(!length(tb$unused) && !length(left))
}

#' Set the environment variable that tells affiliations() a render of the
#' package is running, until the calling function returns. Quarto runs knitr
#' in a process of its own, and the variable is what reaches it.
#' @noRd
.rendering <- function(envir = parent.frame()) {
  old <- Sys.getenv("EASYPAPER_RENDER", unset = NA)
  Sys.setenv(EASYPAPER_RENDER = "true")
  do.call(base::on.exit, list(bquote(
    if (is.na(.(old))) Sys.unsetenv("EASYPAPER_RENDER")
    else Sys.setenv(EASYPAPER_RENDER = .(old))), add = TRUE), envir = envir)
  invisible(old)
}

#' The affiliations of the manuscript, under the authors
#'
#' Writes the affiliations and the correspondence line of the title block,
#' numbered from the `affiliations:` of each author in the YAML of
#' `manuscript.qmd`. The template calls it in a chunk right under the YAML,
#' and every render fills it in; you write the authors and never a number:
#'
#' ```yaml
#' author:
#'   - name: Ada Lovelace
#'     affiliations: [ecology]
#'     email: ada@example.org
#'     corresponding: true
#'   - name: Alan Turing
#'     affiliations: [ecology, institute]
#' affiliations:
#'   - id: ecology
#'     address: University X, Department of Ecology, City, Country
#'   - id: institute
#'     address: Institute Y, City, Country
#' ```
#'
#' comes out as `Ada Lovelace^1,*^, Alan Turing^1,2^` on one line, with
#' `^1^ University X, ...`, `^2^ Institute Y, ...` and
#' `^*^ Correspondence: ada@example.org` under it -- the markdown of the
#' superscripts. The affiliations are numbered in the order the
#' authors name them. Each affiliation is one line, `address:`, written as the
#' paper prints it. It may also be written in place, quoted, as
#' `affiliations: ["University X, City"]`, or with Quarto's own fields
#' (`department:`, `name:`, `city:`, `country:` ...), joined department
#' first, then the name, the address, the city and the country.
#'
#' In a `.docx` they have a paragraph style of their own, *Affiliation*:
#' the body text of the Word template without its first-line indent, which
#' you can restyle in Word for every affiliation at once.
#'
#' A double-blind main text leaves the chunk out, and the title page of
#' [make_submission()] is given it.
#'
#' Quarto's own preview, [preview()] or `quarto preview`, gets nothing from
#' it: there Quarto draws the title block itself.
#'
#' @param path The project, or any folder inside it. While a document is
#'   being rendered, the project of that document.
#' @return The affiliations as markdown: for the chunk to print while a
#'   render of the package runs, and nothing in any other render; printed and
#'   returned invisibly when called from the console.
#' @examples
#' dir <- file.path(tempdir(), "my_paper")
#' create_paper(dir, authors = c("Ada Lovelace", "Alan Turing"), git = FALSE)
#' affiliations(dir)
#' unlink(dir, recursive = TRUE)
#' @export
affiliations <- function(path = ".") {
  input <- knitr::current_input(dir = TRUE)
  knitting <- !is.null(input)
  if (knitting && !nzchar(Sys.getenv("EASYPAPER_RENDER"))) {
    return(invisible(NULL))
  }
  if (knitting) path <- dirname(input)
  own <- rmarkdown::yaml_front_matter(file.path(.find_root(path),
                                                "manuscript.qmd"))
  tb <- .title_block(own)
  if (!length(tb$lines)) return(invisible(NULL))
  md <- paste(tb$lines, collapse = "\n\n")
  if (knitting) {
    # A paragraph style of their own in Word, "Affiliation": .repair_docx()
    # bases it on the template's body text, without its first-line indent.
    # Elsewhere the div is only a div.
    return(knitr::asis_output(paste0('::: {custom-style="Affiliation"}\n',
                                     md, "\n:::\n")))
  }
  cat(tb$lines, sep = "\n")
  invisible(md)
}

#' The short title of the manuscript -- `short-title:` in its YAML, the
#' running head some journals ask for -- or NULL when there is none.
#' @noRd
.short_title <- function(own) {
  st <- own[["short-title"]]
  if (is.null(st)) return(NULL)
  st <- trimws(paste(unlist(st), collapse = " "))
  if (nzchar(st)) st
}

#' A front matter with the short title under the title, as a line of the
#' title itself. In a .docx it is set in the title's own font and size, after
#' a hard line break: a subtitle would take a style of its own. In the .html
#' and the .pdf it is a size smaller and set a little apart, in a span the
#' page's CSS sizes and in LaTeX's \large after a gap. The plain title stays
#' the document's name -- the tab of the .html, the title of the .pdf -- as
#' `pagetitle` and `title-meta`. Nothing changes when there is no short
#' title. The key itself goes, being Quarto's business no more than the
#' easypaper: block is.
#' @noRd
.with_short_title <- function(yml, own, fmt = "docx") {
  yml[["short-title"]] <- NULL
  st <- .short_title(own)
  if (is.null(st)) return(yml)
  line  <- paste("Short title:", st)
  title <- trimws(paste(unlist(yml$title %or% own$title), collapse = " "))
  if (!nzchar(title)) {
    yml$title <- line
    return(yml)
  }
  # The name is plain text: pandoc prints these as they are formatted, and
  # the tab of a browser would show *Formica* as <em>Formica</em>.
  plain <- gsub("(?<!\\\\)[*_`]", "", title, perl = TRUE)
  yml$pagetitle      <- yml$pagetitle %or% plain
  yml[["title-meta"]] <- yml[["title-meta"]] %or% plain
  yml$title <- switch(
    fmt,
    # A span of its own, sized by the CSS below.
    html = paste0(title, " [", line, "]{.short-title}"),
    # A gap and a smaller size, in LaTeX; the words stay markdown, so pandoc
    # escapes what LaTeX would read as a command. `\large{}` and not
    # `\large `: pandoc trims the space that would end the command.
    pdf  = paste0(title, "`\\\\[0.8em]{\\large{}`{=latex}", line, "`}`{=latex}"),
    # Pandoc reads a backslash at the end of a line as a line break, in
    # metadata as in the text.
    paste0(title, "\\\n", line))
  if (identical(fmt, "html")) {
    b <- yml$format$html
    if (!is.list(b)) b <- list()
    inc <- b[["include-in-header"]]
    if (is.list(inc) && !is.null(names(inc))) inc <- list(inc)
    b[["include-in-header"]] <- c(as.list(inc), list(list(text = SHORT_TITLE_CSS)))
    yml$format$html <- b
  }
  yml
}

#' The look of the short title in the .html: a size smaller than the title,
#' on a line of its own, a little apart from it.
#' @noRd
SHORT_TITLE_CSS <- paste0(
  "<style>\n",
  ".title .short-title { display: block; font-size: 0.65em; ",
  "font-weight: normal; margin-top: 0.6em; }\n",
  "</style>")
