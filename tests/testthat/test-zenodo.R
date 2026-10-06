# deposit_zenodo(), against a Zenodo that lives in this file: every call to
# the API is recorded and answered the way Zenodo answers it.

fake_zenodo <- function(published = FALSE) {
  calls <- list()
  dep <- list(
    id = 123L, submitted = published,
    links = list(bucket = "https://zenodo.test/api/files/bucket-1",
                 html = "https://zenodo.test/deposit/123"),
    files = list(list(links = list(
      self = "https://zenodo.test/api/deposit/depositions/123/files/old"))),
    metadata = list(prereserve_doi = list(doi = "10.5281/zenodo.123")))
  api <- function(method, url, token, body = NULL, file = NULL,
                  missing_ok = FALSE) {
    calls[[length(calls) + 1L]] <<- list(method = method, url = url,
                                         token = token, body = body,
                                         file = file)
    if (method == "GET") return(dep)
    if (method == "POST") return(utils::modifyList(dep, list(files = list())))
    if (method == "PUT" && !is.null(body)) {
      d <- dep
      # Zenodo answers the request with the DOI it reserved.
      d$metadata <- utils::modifyList(
        body$metadata, list(prereserve_doi = list(doi = "10.5281/zenodo.123")))
      return(d)
    }
    invisible(NULL)
  }
  list(api = api, calls = function() calls)
}

zenodo_project <- function() {
  p <- new_project(title = "Chemical mimicry in ants",
                   authors = c("Ada Lovelace", "Alan Turing"))
  ms <- readLines(file.path(p, "manuscript.qmd"))
  # The ORCID iD written where the template leaves its place.
  i <- grep('^  - name: "Ada Lovelace"', ms)
  i <- i + grep("^    orcid:", ms[-seq_len(i)])[1]
  ms[i] <- "    orcid: 0000-0000-0000-0000"
  ms <- sub("Institution 1, Department, City, Country", "University X, Spain", ms)
  writeLines(ms, file.path(p, "manuscript.qmd"))
  writeLines(c("Ants, ants.", "", "**Keywords:** ants, mimicry"),
             file.path(p, "_sections", "01_abstract.qmd"))
  writeLines(c("<!-- Example: doi:10.5281/zenodo.XXXXXXX -->",
               "Data and code are archived at Zenodo (doi:10.5281/zenodo.XXXXXXX)."),
             file.path(p, "_sections", "09_data_availability.qmd"))
  dir.create(file.path(p, "submission", "Oryx"), recursive = TRUE)
  writeLines("zip", file.path(p, "submission", "Oryx", "data_and_code.zip"))
  p
}

test_that("deposit_zenodo() reserves a DOI on a draft and never publishes", {
  p <- zenodo_project()
  z <- fake_zenodo()
  local_mocked_bindings(.zenodo_api = z$api)
  expect_message(out <- deposit_zenodo(token = "secret", path = p),
                 "Reserved DOI: 10.5281/zenodo.123")
  expect_identical(out, list(id = 123L, doi = "10.5281/zenodo.123",
                             url = "https://zenodo.test/deposit/123"))
  calls <- z$calls()
  expect_identical(vapply(calls, `[[`, "", "method"), c("POST", "PUT", "PUT"))
  expect_true(all(vapply(calls, `[[`, "", "token") == "secret"))
  # A new deposit, with its DOI reserved; never an action that publishes.
  expect_identical(calls[[1]]$url, "https://zenodo.org/api/deposit/depositions")
  expect_true(calls[[1]]$body$metadata$prereserve_doi)
  expect_false(any(grepl("publish", vapply(calls, `[[`, "", "url"))))
  # The compendium into the deposit's bucket.
  expect_identical(calls[[2]]$url,
                   "https://zenodo.test/api/files/bucket-1/data_and_code.zip")
  expect_identical(basename(calls[[2]]$file), "data_and_code.zip")
  # The description, from the manuscript.
  m <- calls[[3]]$body$metadata
  expect_identical(m$title, "Chemical mimicry in ants")
  expect_identical(m$upload_type, "dataset")
  expect_identical(m$license, "cc-by-4.0")
  # The licence of LICENSE.txt, the one the data's metadata carry too.
  writeLines("CC0 1.0 Universal", file.path(p, "LICENSE.txt"))
  expect_identical(in_project(p, .zenodo_metadata())$license, "cc0-1.0")
  writeLines("All rights reserved.", file.path(p, "LICENSE.txt"))
  expect_identical(in_project(p, .zenodo_license()), "cc-by-4.0")
  expect_identical(m$access_right, "open")
  expect_identical(unlist(m$keywords), c("ants", "mimicry"))
  expect_identical(m$creators[[1]],
                   list(name = "Lovelace, Ada", affiliation = "University X, Spain",
                        orcid = "0000-0000-0000-0000"))
  expect_identical(m$creators[[2]]$name, "Turing, Alan")
  expect_null(m$creators[[2]]$orcid)
  # An ORCID Zenodo cannot read would refuse the whole deposit: it stays out,
  # and the call says so. An X at the end is a checksum, and is fine.
  own <- list(author = list(list(name = "Ada Lovelace", orcid = "XXXX-XXXX-XXXX-XXXX"),
                            list(name = "Alan Turing", orcid = "https://orcid.org/0000-0002-0000-000X")))
  expect_warning(cr <- .zenodo_creators(own, warn = TRUE), "Ada Lovelace.*not an ORCID iD")
  expect_null(cr[[1]]$orcid)
  expect_identical(cr[[2]]$orcid, "0000-0002-0000-000X")
  expect_no_warning(.zenodo_creators(own))
  # Recorded in _quarto.yml, and written where the text has the placeholder.
  in_project(p, {
    expect_identical(.config("zenodo-deposit"), "123")
    expect_identical(.config("data-doi"), "10.5281/zenodo.123")
  })
  # In the text, not in its comments.
  expect_identical(readLines(file.path(p, "_sections", "09_data_availability.qmd")),
                   c("<!-- Example: doi:10.5281/zenodo.XXXXXXX -->",
                     "Data and code are archived at Zenodo (doi:10.5281/zenodo.123)."))
  expect_identical(.outside_comments("a <!-- a --> a", function(x) gsub("a", "b", x)),
                   "b <!-- a --> b")
  expect_identical(.outside_comments("<!--\na\n-->", toupper), "<!--\na\n-->")
  # The rest of _quarto.yml, comments included, is as it was.
  y <- readLines(file.path(p, "_quarto.yml"))
  expect_true(any(grepl("^  # The sections a double-blind submission moves", y)))
  expect_false(is.null(yaml::read_yaml(file.path(p, "_quarto.yml"))$crossref))
})

test_that("the deposit takes the short title when there is one", {
  p <- zenodo_project()
  ms <- readLines(file.path(p, "manuscript.qmd"))
  ms <- sub('^# short-title: .*', 'short-title: "Ant mimicry"', ms)
  writeLines(ms, file.path(p, "manuscript.qmd"))
  z <- fake_zenodo()
  local_mocked_bindings(.zenodo_api = z$api)
  suppressMessages(deposit_zenodo(token = "secret", path = p))
  m <- z$calls()[[3]]$body$metadata
  expect_identical(m$title, "Ant mimicry")
  # The description still names the manuscript by its title.
  expect_match(m$description, "<em>Chemical mimicry in ants</em>", fixed = TRUE)
})

test_that("a second call replaces the file of the same draft", {
  p <- zenodo_project()
  local_mocked_bindings(.zenodo_api = fake_zenodo()$api)
  suppressMessages(deposit_zenodo(token = "secret", path = p))
  z <- fake_zenodo()
  local_mocked_bindings(.zenodo_api = z$api)
  suppressMessages(deposit_zenodo(token = "secret", path = p))
  calls <- z$calls()
  expect_identical(vapply(calls, `[[`, "", "method"),
                   c("GET", "DELETE", "PUT", "PUT"))
  expect_identical(calls[[1]]$url, "https://zenodo.org/api/deposit/depositions/123")
  expect_identical(calls[[2]]$url,
                   "https://zenodo.test/api/deposit/depositions/123/files/old")
})

test_that("a published deposit is left alone", {
  p <- zenodo_project()
  local_mocked_bindings(.zenodo_api = fake_zenodo()$api)
  suppressMessages(deposit_zenodo(token = "secret", path = p))
  local_mocked_bindings(.zenodo_api = fake_zenodo(published = TRUE)$api)
  expect_error(deposit_zenodo(token = "secret", path = p),
               "already published.*new version")
})

test_that("the sandbox is for trying, and its DOI never reaches the text", {
  p <- zenodo_project()
  z <- fake_zenodo()
  local_mocked_bindings(.zenodo_api = z$api)
  expect_message(deposit_zenodo(sandbox = TRUE, token = "secret", path = p),
                 "sandbox")
  expect_match(z$calls()[[1]]$url, "^https://sandbox.zenodo.org/api/")
  in_project(p, {
    expect_identical(.config("zenodo-sandbox-deposit"), "123")
    expect_null(.config("zenodo-deposit"))
    expect_null(.config("data-doi"))
  })
  expect_true(all(grepl("XXXXXXX", readLines(file.path(
    p, "_sections", "09_data_availability.qmd")), fixed = TRUE)))
})

test_that("it says what it needs: a token, and a compendium", {
  p <- zenodo_project()
  old <- Sys.getenv(c("ZENODO_TOKEN", "ZENODO_SANDBOX_TOKEN"), unset = NA)
  Sys.unsetenv(c("ZENODO_TOKEN", "ZENODO_SANDBOX_TOKEN"))
  on.exit(for (k in names(old)) if (!is.na(old[[k]])) {
    do.call(Sys.setenv, stats::setNames(list(old[[k]]), k))
  }, add = TRUE)
  expect_error(deposit_zenodo(path = p), "ZENODO_TOKEN=")
  expect_error(deposit_zenodo(sandbox = TRUE, path = p), "ZENODO_SANDBOX_TOKEN=")
  Sys.setenv(ZENODO_TOKEN = "from-renviron")
  z <- fake_zenodo()
  local_mocked_bindings(.zenodo_api = z$api)
  suppressMessages(deposit_zenodo(path = p))
  expect_identical(z$calls()[[1]]$token, "from-renviron")
  unlink(file.path(p, "submission"), recursive = TRUE)
  expect_error(deposit_zenodo(token = "secret", path = p),
               "No data_and_code.zip in submission/")
  expect_error(deposit_zenodo(file = "nope.zip", token = "secret", path = p),
               "does not exist")
})
