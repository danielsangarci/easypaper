# ---------------------------------------------------------------------------
# The data deposit on Zenodo: a draft with the compendium in it and a DOI
# reserved, so the manuscript can cite the data before they are published.
# ---------------------------------------------------------------------------

#' Reserve the DOI of the data deposit on Zenodo
#'
#' Uploads the data and code compendium -- `data_and_code.zip`, which
#' [make_submission()] and [make_preprint()] build -- to a new Zenodo deposit,
#' fills in its description from the project, and reserves its DOI, so the
#' manuscript can cite the data before they are published. It never
#' publishes: the deposit stays a draft until you review it on Zenodo and
#' press Publish there, which cannot be undone. Nothing in the package needs
#' it; it runs only when you call it.
#'
#' The description comes from the manuscript: the title (the short title,
#' `short-title:`, when there is one; the title otherwise), the authors with
#' their affiliations and ORCID (`orcid:` on an author), the keywords, and
#' the licence of the data, CC BY 4.0. The deposit and its DOI are recorded
#' in the `easypaper:` block of `_quarto.yml`, so a second call -- after the
#' data changed -- replaces the file of the same draft instead of opening
#' another. A deposit already published is left alone: a new version of it
#' is made on Zenodo.
#'
#' The DOI is written into the text wherever it says `10.5281/zenodo.XXXXXXX`
#' -- the placeholder of the data availability statement -- and printed, to
#' cite it wherever else it belongs.
#'
#' It needs a personal access token of Zenodo, with the scopes
#' `deposit:write` and `deposit:actions`: create one at
#' <https://zenodo.org/account/settings/applications/tokens/new/> and put it in
#' your `.Renviron` as `ZENODO_TOKEN=...` (`usethis::edit_r_environ()` opens
#' it). To try it first, use Zenodo's sandbox, a copy of the site for tests:
#' a token from <https://sandbox.zenodo.org> as `ZENODO_SANDBOX_TOKEN`, and
#' `sandbox = TRUE`. A sandbox DOI does not resolve, so it is never written
#' into the text.
#'
#' @param file The compendium to upload. `NULL`, the default, takes the
#'   newest `data_and_code.zip` in `submission/`.
#' @param sandbox `TRUE` deposits on <https://sandbox.zenodo.org>, to try it.
#' @param token The personal access token. `NULL`, the default, reads
#'   `ZENODO_TOKEN`, or `ZENODO_SANDBOX_TOKEN` with `sandbox = TRUE`.
#' @param path The project, or any folder inside it. The working directory by
#'   default, which is the project root once its `.Rproj` is open.
#' @return A list with the deposit's `id`, the reserved `doi` and the `url`
#'   of the draft, invisibly.
#' @export
#' @examples
#' \dontrun{
#' make_submission()            # builds submission/<Journal>/data_and_code.zip
#' deposit_zenodo(sandbox = TRUE)   # try it on the sandbox first
#' deposit_zenodo()                 # the real one: a draft, and its DOI
#' }
deposit_zenodo <- function(file = NULL, sandbox = FALSE, token = NULL,
                           path = ".") {
  .enter_project(path)
  .check_flag(sandbox, "sandbox")
  if (!requireNamespace("curl", quietly = TRUE)) {
    stop("deposit_zenodo() needs the curl package: install.packages(\"curl\").",
         call. = FALSE)
  }
  token <- .zenodo_token(token, sandbox)
  file  <- .compendium(file)
  api   <- if (sandbox) "https://sandbox.zenodo.org/api" else "https://zenodo.org/api"
  key   <- if (sandbox) "zenodo-sandbox-deposit" else "zenodo-deposit"
  meta  <- c(.zenodo_metadata(), list(prereserve_doi = TRUE))

  # The draft this project already has, if it is still a draft.
  dep <- NULL
  id  <- .config(key)
  if (!is.null(id) && nzchar(as.character(id))) {
    dep <- .zenodo_api("GET", sprintf("%s/deposit/depositions/%s", api, id),
                       token, missing_ok = TRUE)
    if (!is.null(dep) && isTRUE(dep$submitted)) {
      stop("The deposit ", id, " is already published, and a published ",
           "deposit cannot be changed: make a new version of it on Zenodo (",
           dep$links$html, ").", call. = FALSE)
    }
  }
  if (is.null(dep)) {
    dep <- .zenodo_api("POST", paste0(api, "/deposit/depositions"), token,
                       body = list(metadata = meta))
  } else {
    # Its old files go: the compendium replaces them.
    for (f in dep$files) {
      .zenodo_api("DELETE", f$links$self, token)
    }
  }
  .zenodo_api("PUT", paste0(dep$links$bucket, "/", basename(file)), token,
              file = file)
  dep <- .zenodo_api("PUT", sprintf("%s/deposit/depositions/%s", api, dep$id),
                     token, body = list(metadata = meta))
  doi <- dep$metadata$prereserve_doi$doi
  url <- dep$links$html

  .set_config(key, dep$id)
  if (!sandbox && !is.null(doi)) {
    .set_config("data-doi", doi)
    done <- .fill_doi(doi)
  } else {
    done <- character(0)
  }
  message("Zenodo draft ", dep$id, if (sandbox) " (sandbox)", ": ", url, "\n",
          "Reserved DOI: ", doi,
          if (length(done)) paste0("\nWritten into ", paste(done, collapse = ", ")),
          if (sandbox) "\nA sandbox DOI does not resolve, so the text is left alone.",
          "\nIt is a draft: review it on Zenodo and press Publish there.")
  invisible(list(id = dep$id, doi = doi, url = url))
}

#' The personal access token, or a stop that says where to get one.
#' @noRd
.zenodo_token <- function(token, sandbox) {
  var <- if (sandbox) "ZENODO_SANDBOX_TOKEN" else "ZENODO_TOKEN"
  if (is.null(token)) token <- Sys.getenv(var)
  if (!is.character(token) || length(token) != 1L || !nzchar(token)) {
    site <- if (sandbox) "https://sandbox.zenodo.org" else "https://zenodo.org"
    stop("No Zenodo token. Create one at ", site,
         "/account/settings/applications/tokens/new/ with the scopes ",
         "deposit:write and deposit:actions, and put it in your .Renviron as ",
         var, "=... (usethis::edit_r_environ() opens it).", call. = FALSE)
  }
  token
}

#' The compendium to upload: the file named, or the newest one in
#' submission/.
#' @noRd
.compendium <- function(file) {
  if (!is.null(file)) {
    .check_string(file, "file")
    if (!file.exists(file)) stop("`", file, "` does not exist.", call. = FALSE)
    return(normalizePath(file))
  }
  zips <- list.files(.p("submission"), "^data_and_code[.]zip$",
                     recursive = TRUE, full.names = TRUE)
  if (!length(zips)) {
    stop("No data_and_code.zip in submission/: make_submission() or ",
         "make_preprint() builds it.", call. = FALSE)
  }
  zips[which.max(file.mtime(zips))]
}

#' The deposit's description, from the manuscript.
#' @noRd
.zenodo_metadata <- function() {
  own   <- rmarkdown::yaml_front_matter(.master())
  title <- paste(own$title, collapse = " ")
  kw    <- .keywords()
  kw    <- kw[!grepl("^keyword[0-9]+$", kw)]
  meta <- list(
    upload_type  = "dataset",
    title        = .short_title(own) %or% title,
    creators     = .zenodo_creators(own),
    description  = paste0("<p>Data and code of the manuscript <em>", title,
                          "</em>: the data, their metadata, and the code that ",
                          "reproduces the analysis, with the versions of the ",
                          "packages it used (renv.lock).</p>"),
    access_right = "open",
    license      = "cc-by-4.0")
  if (length(kw)) meta$keywords <- as.list(kw)
  meta
}

#' The authors as Zenodo wants them: "Family, Given", with an affiliation and
#' an ORCID when the manuscript gives them.
#' @noRd
.zenodo_creators <- function(own) {
  a <- own$author
  if (is.null(a)) return(list())
  if (!is.list(a) || !is.null(names(a))) a <- list(a)
  aff <- .author_affiliations(own)
  out <- lapply(seq_along(a), function(i) {
    x <- a[[i]]
    n <- .person_name(x)
    if (is.null(n)) return(NULL)
    n <- trimws(gsub("[\\\\*,]+$", "", gsub("\\^[^^]*\\^", "", n)))
    nm <- x[["name"]]
    name <- if (is.list(nm) && !is.null(nm$family)) {
      paste0(nm$family, if (!is.null(nm$given)) paste0(", ", nm$given))
    } else {
      w <- strsplit(n, "\\s+")[[1]]
      if (length(w) > 1L) {
        paste0(w[length(w)], ", ", paste(w[-length(w)], collapse = " "))
      } else n
    }
    c(list(name = name),
      if (length(aff[[i]])) list(affiliation = paste(aff[[i]], collapse = "; ")),
      if (is.list(x) && is.character(x$orcid)) list(orcid = x$orcid[1]))
  })
  Filter(Negate(is.null), out)
}

#' Each author's affiliations as text, from the structured YAML; empty for
#' authors written with their marks in their names.
#' @noRd
.author_affiliations <- function(own) {
  a <- own$author
  if (!is.list(a) || !is.null(names(a))) a <- list(a)
  pool <- own$affiliations
  if (!is.null(pool) && (!is.list(pool) || !is.null(names(pool)))) pool <- list(pool)
  ids <- vapply(pool, function(p) {
    if (is.list(p) && !is.null(p$id)) as.character(p$id)[1] else NA_character_
  }, character(1))
  lapply(a, function(x) {
    refs <- if (is.list(x)) x[["affiliations"]] %or% x[["affiliation"]]
    if (is.null(refs)) return(character(0))
    if (is.list(refs) && !is.null(names(refs))) refs <- list(refs)
    else if (!is.list(refs)) refs <- as.list(refs)
    out <- vapply(refs, function(r) {
      id <- if (is.list(r) && !is.null(r$ref)) as.character(r$ref)[1]
            else if (!is.list(r)) as.character(r)[1]
      k <- if (!is.null(id)) match(id, ids) else NA
      .affiliation_text(if (!is.na(k)) pool[[k]] else r)
    }, character(1))
    out[!is.na(out)]
  })
}

#' The DOI written into the text wherever it has the placeholder -- the text
#' that is printed, not its comments, where the template only explains it.
#' Returns the files it changed.
#' @noRd
.fill_doi <- function(doi) {
  files <- list.files(.p("_sections"), "[.]qmd$", full.names = TRUE)
  changed <- character(0)
  for (f in files) {
    txt <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    new <- .outside_comments(txt, function(x) {
      gsub("10.5281/zenodo.XXXXXXX", doi, x, fixed = TRUE)
    })
    if (!identical(new, txt)) {
      writeLines(strsplit(new, "\n", fixed = TRUE)[[1]], f, useBytes = TRUE)
      changed <- c(changed, basename(f))
    }
  }
  changed
}

#' Apply `fn` to the parts of `txt` outside HTML comments.
#' @noRd
.outside_comments <- function(txt, fn) {
  m <- gregexpr("(?s)<!--.*?-->", txt, perl = TRUE)[[1]]
  if (m[1] < 0) return(fn(txt))
  starts <- c(1L, m + attr(m, "match.length"))
  ends   <- c(m - 1L, nchar(txt))
  out <- character(0)
  for (i in seq_along(starts)) {
    out <- c(out, fn(substr(txt, starts[i], ends[i])))
    if (i <= length(m)) out <- c(out, substr(txt, m[i], m[i] + attr(m, "match.length")[i] - 1L))
  }
  paste(out, collapse = "")
}

#' Set one key of the easypaper: block of _quarto.yml, keeping every other
#' line -- and comment -- as it is.
#' @noRd
.set_config <- function(key, value) {
  f <- .p("_quarto.yml")
  l <- readLines(f, warn = FALSE)
  line <- sprintf('  %s: "%s"', key, value)
  hit <- grep(paste0("^  ", key, ":"), l)
  if (length(hit)) {
    l[hit[1]] <- line
  } else {
    start <- grep("^easypaper:\\s*$", l)
    l <- if (length(start)) append(l, line, after = start[1])
         else c(sub("\\s+$", "", l), "", "easypaper:", line)
  }
  writeLines(l, f)
  invisible(TRUE)
}

#' One call to the Zenodo API. JSON in and out; a file is sent as it is. A
#' failure stops with what Zenodo said; `missing_ok` turns a 404 into NULL.
#' @noRd
.zenodo_api <- function(method, url, token, body = NULL, file = NULL,
                        missing_ok = FALSE) {
  h <- curl::new_handle()
  curl::handle_setheaders(h, Authorization = paste("Bearer", token))
  curl::handle_setopt(h, customrequest = method)
  if (!is.null(body)) {
    curl::handle_setheaders(h, Authorization = paste("Bearer", token),
                            "Content-Type" = "application/json")
    curl::handle_setopt(h, postfields = jsonlite::toJSON(body, auto_unbox = TRUE,
                                                        null = "null"))
  } else if (!is.null(file)) {
    curl::handle_setheaders(h, Authorization = paste("Bearer", token),
                            "Content-Type" = "application/octet-stream")
    curl::handle_setopt(h, postfields = readBin(file, "raw", file.size(file)))
  }
  r <- curl::curl_fetch_memory(url, handle = h)
  if (missing_ok && r$status_code == 404L) return(NULL)
  txt <- rawToChar(r$content)
  if (r$status_code >= 400L) {
    msg <- tryCatch(jsonlite::fromJSON(txt)$message, error = function(e) txt)
    stop("Zenodo answered ", r$status_code, " to ", method, " ", url, ": ",
         msg, call. = FALSE)
  }
  if (!nzchar(txt)) return(invisible(NULL))
  jsonlite::fromJSON(txt, simplifyVector = FALSE)
}
