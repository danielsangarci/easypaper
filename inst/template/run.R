# ===========================================================================
# run.R -- the commands, ready to run.
#
# Nothing in this project calls this file: it is a cheat sheet. Open it, put
# the cursor on the line you want and press Cmd+Enter (Ctrl+Enter on Windows).
# The point is that you never have to remember a function name or an argument.
#
# Do NOT source() it: that would fire every render, one after another. The
# guard below stops you if you try.
#
# The actual code lives in make.R, R/submission.R, R/convert_data.R and
# R/crossref_styles.R.
#
# What each argument does, in tables and with its default, is in the Get
# started guide: https://danielsangarci.github.io/easypaper/articles/easypaper.html
# ===========================================================================

if (sys.nframe() > 0L) {
  stop("run.R is a cheat sheet: run its lines one at a time, do not source() it.",
       call. = FALSE)
}


# --- 0. ALWAYS FIRST -------------------------------------------------------
# Loads every function below. Repeat it after each restart of R (if you get
# 'could not find function', this is what you forgot).

source("make.R")


# --- 0b. GETTING DATA IN ---------------------------------------------------
# data/ is the folder that publishes: what is in it is what the analysis
# reads, what the metadata describes and what the deposit carries. This brings
# an original in, converted or copied. It does NOT run by itself.
#
# The path is relative to the project root, or absolute. Your originals live
# wherever you keep them -- the project does not publish them, so it does not
# prescribe a place. They are never moved, edited or converted in place.
#
# What it does with each format, and how to teach it one more, is at the top
# of R/convert_data.R.

convert_data("originals/counts.xlsx")          # one workbook, one .csv/sheet
convert_data("originals")                      # a whole folder at once
convert_data("~/Drive/plots.gpkg")             # already open: copied as it is
convert_data("originals", overwrite = TRUE)    # rebuild, ignoring what is there
convert_data("originals", also = "las")        # one more extension as open


# --- 1. WHILE WRITING ------------------------------------------------------
# Fast feedback. Not what you send to anyone.

render_html()          # .html in output/, seconds instead of minutes
preview()              # live preview: re-renders on every save. Esc to stop
list_journals()        # which .csl you have in references_styles/


# --- 2. FULL RENDERS -------------------------------------------------------
# journal       = name of a .csl, without the extension (list_journals())
# caption_style = "default" | "abbrev" | "nature" | "compact"
# suppl_figures = "separate" or "main": whether the supplementary figures and
#                 tables travel with the supplement or stay at the end of the
#                 manuscript
#
# One document per section, always: the manuscript in output/ and the
# supplement or supplements beside it, each with its own reference list. They
# are never joined into one file. Doing that means handing both to pandoc,
# which rebuilds the document instead of copying it and loses every column
# width on the way -- the tables reach Word with the headings broken across
# two lines.

render_docx("myrmecological-news")                 # -> output/*.docx
render_docx("ecology-letters", "abbrev")           # another journal, "Fig. 1."
render_pdf("myrmecological-news")                  # -> output/preprint.pdf
render_supplementary("myrmecological-news")        # the supplement(s) on their
                                                   # own: one document per
                                                   # _sections/8*suppl*.qmd
render_html("myrmecological-news", "nature")       # "Figure 1 | caption"

make_all()                                         # docx + pdf + supplement
make_all("ecology-letters", "abbrev")              # the same, another journal

# make_all() is those four renders and nothing else. It writes into output/,
# and it does NOT build a submission: that is section 3, and it is separate on
# purpose -- see the note there.
#
# All of these record renv.lock when they finish: a document somebody else
# will read carries the environment it came out of. render_html() above does
# not, on purpose -- it is also what you render after restoring an old
# environment to look into something, and it must not overwrite your record.


# --- 3. SUBMISSION ---------------------------------------------------------
# Not part of make_all(). A render is disposable; a submission is a moment you
# will want to return to: it rewrites renv.lock to record the environment this
# version came out of, and labels every file it writes. That does not belong
# in a command you run after fixing a typo.
#
# label         = name of the folder inside submission/ and the suffix of every
#                 file in it. Defaults to "default" so a trial run cannot be
#                 mistaken for a real submission
# figure_format = "tiff" (what journals ask for) | "png" | "jpg"
# blinded       = TRUE splits it for double-blind review: title_*.docx from the
#                 title to just before the Abstract, main_*.docx opening with
#                 the title alone and no author anywhere

# suppl_figures = "separate" leaves the supplementary figures and tables in
#                 their own document, and rewrites @sfig-map in the main text
#                 to the plain "Figure S1"
#                 "main" keeps them at the end of main_*.docx instead.
#                 Supplementary TEXT (an extended Methods) always goes out on
#                 its own, with its own reference list -- see the README

make_submission()                                  # trial -> submission/default/
make_submission("myrmecological-news", suppl_figures = "main")
                                                   # ^ floats in the main text
make_submission("myrmecological-news", label = "MyrmecologicalNews")
                                                   # ^ the real submission
make_submission("myrmecological-news", label = "MyrmecologicalNews", snapshot = FALSE)
                                                   # ^ do NOT touch renv.lock
make_submission("ecology-letters", label = "EcologyLetters",
                figure_format = "png", blinded = FALSE)


# --- 3b. PREPRINT DEPOSIT --------------------------------------------------
# Same idea as a submission, for the other destination. The manuscript comes
# out as ONE signed .pdf -- a preprint carries its authors -- with the
# supplement, the figures and the data and code compendium beside it. There is
# no cover letter: there is no editor. The folder's README says what goes to
# the preprint server and what goes to the data repository.

make_preprint()                                    # -> submission/bioRxiv/
make_preprint(label = "EcoEvoRxiv")                 # another server
make_preprint(label = "bioRxiv_v2")                 # the revised version
make_preprint(suppl_figures = "main")              # figures at the end of the pdf


# --- 4. CHECKS -------------------------------------------------------------
# The three renders run these on their own. Call them when you want to know
# before waiting for a render.

check_citations()      # @keys with no entry in references/, and vice versa
check_crossrefs()      # @fig-/@tbl- with no target, and figures nobody cites
check_title()          # does title_page.qmd still match the manuscript?
export_figure_formats()# figures/png/ -> figures/jpg/ and figures/tiff/ at 600 dpi
check_renv()           # is renv.lock there, and does it match what you are using?
check_data()           # files sitting in data/ that nothing reads --
                       # they would travel to the repository anyway


# --- 5. MAINTENANCE --------------------------------------------------------

renv::snapshot()       # record the packages in renv.lock by hand. Rarely
                       # needed now: every render that produces a document
                       # records it, and so does make_submission(). The one
                       # that does NOT is render_html()
clean_cache()          # after touching data/: knitr does NOT notice by itself
sync_licenses()        # copies the authors from the YAML into LICENSE*/README
sync_metadata()        # fills the deposit's metadata with what the project
                       # already knows: title, keywords, authors, variable
                       # names. Runs on every render too; it only ever ADDS,
                       # so what you typed by hand is safe. The rest --units,
                       # descriptions, coverage-- is yours: R/create_metadata.R
export_code()          # analysis_code.R + sessionInfo.txt for the supplement


# --- 6. CO-AUTHORS IN GOOGLE DOCS (trackdown) ------------------------------
# Needs the GitHub version: remotes::install_github("claudiozandonella/trackdown")
# section = the file name in _sections/, with or without the extension

td_upload("2_introduction")     # first upload
td_update("2_introduction")     # overwrite with your local version
td_download("2_introduction")   # bring back their edits BEFORE editing locally


# --- 7. FIRST TIME ONLY ----------------------------------------------------
# renv::init()                  # OPTIONAL: renv's isolated project library.
#                               # Not needed for the lockfile: make_submission()
#                               # writes renv.lock from the library you use
# source("R/create_metadata.R") # dataspice metadata, filled in by hand
