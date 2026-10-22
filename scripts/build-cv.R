# scripts/build-cv.R -- pre-render step for the CV page (base R only).
#
# Quarto runs this from the project root before every render (see
# `pre-render` in _quarto.yml). It:
#
#   1. reads the CV source (`cv_source` below);
#   2. writes cv/_cv-body.md: the CV without its YAML header and raw LaTeX,
#      with headings moved down one level (the page title is the only h1);
#   3. writes cv/_cv-updated.md: "Updated <date>", from the date the CV
#      source was last saved;
#   4. rebuilds files/Somboonkittichai_CV.pdf when it is missing or older
#      than the CV source, by rendering a copy of the source in a temporary
#      folder (so nothing is ever written next to the source). In that copy
#      \cvflagstrue is switched to \cvflagsfalse, so the red \cvflag
#      reminders never print in the public PDF, and the sections listed in
#      pdf_drop_sections (none at present) are left out. The render log is
#      kept in .quarto/build-cv-pdf.log.
#
# Generated files are rewritten only when their content changes, so
# `quarto preview` does not re-render in a loop. Every problem is reported as
# a warning; this script never stops the site render.
#
# The PDF is rendered from a lone copy of the CV source, so the source must
# not rely on other files beside it (images, .bib files and so on).

cv_source <- "../Somboonkittichai_CV.qmd"   # relative to the project root
body_file <- "cv/_cv-body.md"
date_file <- "cv/_cv-updated.md"
pdf_file  <- "files/Somboonkittichai_CV.pdf"
pdf_log   <- ".quarto/build-cv-pdf.log"     # kept copy of the last PDF render log

# Sections of the CV source left out of the CV page on the website. Your own
# CV file keeps them. Write each heading as it appears after "# " in the CV
# source; capitals and spaces at the end do not matter.
web_drop_sections <- c("YOUTH FORUMS AND COMPETITIONS", "REFERENCES")
# Sections left out of the PDF on the website, written the same way. Empty:
# the PDF keeps every section, references included, like your own CV file.
pdf_drop_sections <- character(0)

note <- function(...) cat("[build-cv] ", ..., "\n", sep = "")
warn <- function(...) cat("[build-cv] WARNING: ", ..., "\n", sep = "", file = stderr())

# All paths above are relative to the website folder (the one that holds
# _quarto.yml). Quarto always runs this script from there. When it is run by
# hand from another folder, move to the folder above this script, or stop
# with a clear message instead of writing files in the wrong place.
if (!file.exists("_quarto.yml")) {
  script <- sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE))
  script <- gsub("~+~", " ", script, fixed = TRUE)   # Rscript's encoding of spaces
  root <- if (length(script)) dirname(dirname(normalizePath(script[1], mustWork = FALSE))) else ""
  if (nzchar(root) && file.exists(file.path(root, "_quarto.yml"))) {
    setwd(root)
    note("Working in the website folder: ", root)
  } else {
    stop("[build-cv] run this script from the website folder (the one that holds ",
         "_quarto.yml), for example: Rscript scripts/build-cv.R", call. = FALSE)
  }
}

# Write `text` (UTF-8) to `path` only if it differs from what is there.
write_if_changed <- function(path, text) {
  new <- charToRaw(enc2utf8(text))
  if (file.exists(path)) {
    old <- readBin(path, "raw", n = file.size(path))
    if (identical(old, new)) return(FALSE)
  }
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  writeBin(new, path)
  TRUE
}

# Remove every \cvflag{...} reminder, with the spaces or tabs before it. The
# reminder may hold braces of its own (e.g. \cvflag{check \emph{this}}) or run
# over several lines, so its end is found by counting braces: { adds one, }
# takes one away, and a backslash makes the next character plain text (\{ and
# \} are literal braces).
drop_cvflags <- function(lines) {
  if (!any(grepl("\\cvflag", lines, fixed = TRUE))) return(lines)
  text <- paste(lines, collapse = "\n")
  done <- character()
  repeat {
    hit <- regexpr("[ \t]*\\\\cvflag[ \t]*\\{", text, perl = TRUE)
    if (hit < 0) break
    start <- as.integer(hit)
    after <- start + attr(hit, "match.length")   # first character inside the braces
    chars <- strsplit(substring(text, after), "")[[1]]
    depth <- 1L
    k <- 0L
    while (depth > 0L && k < length(chars)) {
      k <- k + 1L
      ch <- chars[k]
      if (ch == "\\") k <- k + 1L
      else if (ch == "{") depth <- depth + 1L
      else if (ch == "}") depth <- depth - 1L
    }
    if (depth > 0L) {
      # Never closed: drop it to the end of its line.
      eol <- regexpr("\n", substring(text, after), fixed = TRUE)
      k <- if (eol > 0) eol - 1L else length(chars)
      warn("a \\cvflag{ is never closed; it was dropped from the web CV to the end of its line.")
    }
    done <- c(done, substr(text, 1L, start - 1L))
    text <- substring(text, after + k)
  }
  text <- paste(c(done, text), collapse = "")
  regmatches(text, gregexpr("\n", text, fixed = TRUE), invert = TRUE)[[1]]
}

# Remove the sections named in titles (web_drop_sections unless another list
# is given): from their top-level heading ("# REFERENCES") up to the next
# top-level heading or the end.
drop_sections <- function(lines, titles = web_drop_sections) {
  if (!length(titles)) return(lines)
  top <- grepl("^#\\s", lines)
  name <- toupper(trimws(sub("^#\\s+", "", lines)))
  keep <- rep(TRUE, length(lines))
  dropping <- FALSE
  for (i in seq_along(lines)) {
    if (top[i]) dropping <- name[i] %in% toupper(trimws(titles))
    if (dropping) keep[i] <- FALSE
  }
  found <- toupper(trimws(titles)) %in% name[top]
  if (any(!found)) warn("section(s) to leave out not found in the CV: ",
                        paste(titles[!found], collapse = ", "))
  lines[keep]
}

# Turn the CV source (a Quarto/Pandoc Markdown file aimed at PDF) into
# Markdown that the HTML page can include.
convert_cv <- function(lines) {
  # 0. Leave out the sections that are not shown on the website.
  lines <- drop_sections(lines)

  # 1. Drop the YAML front matter.
  first <- which(nzchar(trimws(lines)))[1]
  if (!is.na(first) && grepl("^---\\s*$", lines[first])) {
    ends <- which(grepl("^(---|\\.\\.\\.)\\s*$", lines))
    end <- ends[ends > first][1]
    if (!is.na(end)) lines <- lines[-seq_len(end)]
  }

  # 2. Drop fenced raw LaTeX blocks: from a fence line ending in {=latex}
  #    to its closing fence.
  keep <- rep(TRUE, length(lines))
  i <- 1
  while (i <= length(lines)) {
    open <- regmatches(lines[i], regexec("^\\s*(`{3,}|~{3,})\\s*\\{=latex\\}\\s*$", lines[i]))[[1]]
    if (length(open) == 2) {
      fence <- open[2]
      close_re <- paste0("^\\s*", substr(fence, 1, 1), "{", nchar(fence), ",}\\s*$")
      j <- i + 1
      while (j <= length(lines) && !grepl(close_re, lines[j])) j <- j + 1
      if (j > length(lines)) warn("a raw LaTeX block that starts on line ", i, " is never closed; it was dropped to the end.")
      keep[i:min(j, length(lines))] <- FALSE
      i <- j + 1
    } else {
      i <- i + 1
    }
  }
  lines <- lines[keep]

  # 3. Inline raw LaTeX, e.g. `\\`{=latex} (a line break in the PDF),
  #    becomes a single space.
  lines <- gsub("`[^`]*`\\{=latex\\}", " ", lines, perl = TRUE)

  # 4. \cvnote{X} becomes a small muted note. A literal * at the start of X
  #    is escaped so that it is not read as emphasis.
  lines <- gsub("\\\\cvnote\\{\\*", "\\\\cvnote{\\\\*", lines, perl = TRUE)
  lines <- gsub("\\\\cvnote\\{([^{}]*)\\}", "[\\1]{.cv-note}", lines, perl = TRUE)

  # 5. \cvflag{X} (a reminder that only the PDF draft shows) is removed, also
  #    when X contains braces (drop_cvflags, above).
  lines <- drop_cvflags(lines)

  # 6. Move headings down one level: # EDUCATION becomes an h2 on the page.
  lines <- sub("^(#{1,5})(\\s)", "#\\1\\2", lines, perl = TRUE)

  # 7. Report any LaTeX command still in the text. Pandoc drops raw LaTeX
  #    from HTML, so the command is missing from the web CV together with its
  #    argument (e.g. all of \textbf{Distinction}); the PDF still shows it.
  left <- grep("\\\\[A-Za-z]+", lines, perl = TRUE)
  for (k in left) {
    cmds <- unique(regmatches(lines[k], gregexpr("\\\\[A-Za-z]+", lines[k], perl = TRUE))[[1]])
    several <- length(cmds) > 1
    warn(if (several) "LaTeX commands " else "LaTeX command ", paste(cmds, collapse = ", "),
         if (several) " are" else " is", " DROPPED from the web CV, together with ",
         if (several) "their arguments: " else "its argument: ", trimws(lines[k]))
  }

  # Tidy: no blank lines at the start, exactly one newline at the end.
  first <- which(nzchar(trimws(lines)))[1]
  lines <- if (is.na(first)) character() else lines[first:length(lines)]
  while (length(lines) && !nzchar(trimws(lines[length(lines)]))) lines <- lines[-length(lines)]

  header <- c(
    "<!-- Generated by scripts/build-cv.R from Somboonkittichai_CV.qmd.",
    "     Do not edit this file: edit the CV source and render the site. -->",
    ""
  )
  paste0(paste(c(header, lines), collapse = "\n"), "\n")
}

updated_line <- function(path) {
  when <- as.POSIXlt(file.mtime(path))
  day <- when$mday
  month <- month.name[when$mon + 1]
  year <- when$year + 1900
  iso <- sprintf("%04d-%02d-%02d", year, when$mon + 1, day)
  sprintf("[Updated <time datetime=\"%s\">%d %s %d</time>]{.cv-updated}\n", iso, day, month, year)
}

build_pdf <- function() {
  # Rebuild when the CV source or this script (for example its list of
  # sections to leave out) is newer than the PDF.
  this_script <- "scripts/build-cv.R"
  newest <- max(file.mtime(cv_source), if (file.exists(this_script)) file.mtime(this_script) else -Inf)
  if (file.exists(pdf_file) && file.mtime(pdf_file) >= newest) {
    note("PDF is up to date, not rebuilt: ", pdf_file)
    return(invisible(FALSE))
  }

  quarto <- Sys.which("quarto")
  if (!nzchar(quarto)) {
    bin <- Sys.getenv("QUARTO_BIN_PATH")
    if (nzchar(bin) && file.exists(file.path(bin, "quarto"))) quarto <- file.path(bin, "quarto")
  }
  if (!nzchar(quarto)) {
    warn("quarto was not found, so the PDF was not rebuilt; the existing PDF is kept.")
    return(invisible(FALSE))
  }

  tmp <- tempfile("cv-pdf-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  copy <- file.path(tmp, basename(cv_source))
  file.copy(cv_source, copy)

  # The CV prints its \cvflag{...} reminders in red while \cvflagstrue is
  # set. Switch them off in this copy only (never in the CV source), so they
  # never appear in the public PDF.
  # The sections in pdf_drop_sections are left out of this copy (none at
  # present: the PDF keeps the sections that the CV page leaves out).
  copy_lines <- readLines(copy, encoding = "UTF-8", warn = FALSE)
  copy_lines <- gsub("\\cvflagstrue", "\\cvflagsfalse", copy_lines, fixed = TRUE)
  copy_lines <- drop_sections(copy_lines, pdf_drop_sections)
  writeLines(copy_lines, copy, useBytes = TRUE)

  # The website render sets QUARTO_PROJECT_* variables (project folder, files
  # to render). Clear them so the nested render treats the copy as a
  # stand-alone document, and put them back afterwards.
  vars <- grep("^QUARTO_PROJECT_|^QUARTO_PROFILE$", names(Sys.getenv()), value = TRUE)
  saved <- Sys.getenv(vars, names = TRUE)
  if (length(vars)) Sys.unsetenv(vars)
  on.exit(if (length(saved)) do.call(Sys.setenv, as.list(saved)), add = TRUE)

  # Date the PDF by the day the CV source was last saved, like the web page:
  # with these two variables pdfTeX uses that day for \day, \month and \year,
  # so the PDF's "Updated" line matches the page instead of showing the day
  # the PDF happened to be built. (Noon UTC keeps the calendar day intact.)
  saved_day <- as.POSIXlt(file.mtime(cv_source))
  epoch <- as.numeric(as.POSIXct(sprintf("%04d-%02d-%02d 12:00:00", saved_day$year + 1900,
                                         saved_day$mon + 1, saved_day$mday), tz = "UTC"))
  Sys.setenv(SOURCE_DATE_EPOCH = format(epoch, scientific = FALSE), FORCE_SOURCE_DATE = "1")
  on.exit(Sys.unsetenv(c("SOURCE_DATE_EPOCH", "FORCE_SOURCE_DATE")), add = TRUE)

  log <- file.path(tmp, "render.log")
  note("Rendering the CV PDF (", pdf_file, " is missing or older than the CV source) ...")
  started <- Sys.time()
  status <- tryCatch(
    system2(quarto, c("render", shQuote(copy), "--to", "pdf"),
            stdout = log, stderr = log),
    error = function(e) {
      warn("could not run quarto: ", conditionMessage(e))
      -1L
    }
  )
  seconds <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  built <- sub("\\.qmd$", ".pdf", copy)

  # Keep the render log after the temporary folder is deleted. .quarto/ is
  # ignored by git and by quarto preview, so this never triggers a re-render.
  kept_log <- file.exists(log) && {
    dir.create(dirname(pdf_log), showWarnings = FALSE, recursive = TRUE)
    isTRUE(file.copy(log, pdf_log, overwrite = TRUE))
  }

  if (identical(as.integer(status), 0L) && file.exists(built)) {
    dir.create(dirname(pdf_file), showWarnings = FALSE, recursive = TRUE)
    if (file.copy(built, pdf_file, overwrite = TRUE)) {
      note(sprintf("PDF rebuilt in %.1f s: %s", seconds, pdf_file))
      return(invisible(TRUE))
    }
    warn("the PDF was built but could not be copied to ", normalizePath(pdf_file, mustWork = FALSE),
         "; the existing PDF is kept.")
  } else {
    warn(sprintf("PDF build failed after %.1f s (exit status %s); the existing PDF is kept, so it may be out of date.",
                 seconds, status))
    if (file.exists(log)) {
      # Show the log from its first error line, or its last 40 lines.
      log_lines <- readLines(log, warn = FALSE)
      first_error <- grep("ERROR|LaTeX Error|^!", log_lines, useBytes = TRUE)[1]
      shown <- if (is.na(first_error)) utils::tail(log_lines, 40) else log_lines[first_error:length(log_lines)]
      cat(paste0("    ", shown), sep = "\n", file = stderr())
    }
    if (kept_log) warn("the full render log is in ", normalizePath(pdf_log))
  }
  invisible(FALSE)
}

main <- function() {
  if (!file.exists(cv_source)) {
    warn("CV source not found at ", normalizePath(cv_source, mustWork = FALSE),
         "; the existing CV page files and PDF are kept.")
    # If the includes are missing too, write empty ones so that the next render
    # works. (Quarto reads the includes before this script runs, so on a copy
    # without them, run `Rscript scripts/build-cv.R` once by hand first.)
    for (f in c(body_file, date_file)) if (!file.exists(f)) write_if_changed(f, "\n")
    return(invisible())
  }

  source_lines <- readLines(cv_source, encoding = "UTF-8", warn = FALSE)

  body <- tryCatch(convert_cv(source_lines), error = function(e) {
    warn("could not convert the CV (", conditionMessage(e), "); the existing ", body_file, " is kept.")
    NULL
  })
  if (!is.null(body)) {
    changed <- write_if_changed(body_file, body)
    note(if (changed) "Updated " else "Unchanged: ", body_file)
  }

  changed <- write_if_changed(date_file, updated_line(cv_source))
  note(if (changed) "Updated " else "Unchanged: ", date_file)

  tryCatch(build_pdf(), error = function(e) {
    warn("PDF step failed (", conditionMessage(e), "); the existing PDF is kept.")
  })
}

tryCatch(main(), error = function(e) {
  warn("unexpected problem (", conditionMessage(e), "); the site render continues.")
})
invisible(NULL)
