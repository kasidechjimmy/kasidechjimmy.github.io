# Kasidech Somboonkittichai: academic website

A Quarto website with five tabs: Home, Research, CV, Teaching and Contact.
The design is a single column of text, like a journal page: one serif
typeface (Source Serif 4) on an ivory page, near-black text, thin rules
between sections, and one accent colour (oxblood) for links.

## Where each piece of content lives

| What | File |
|---|---|
| Site settings, the tabs, the includes | `_quarto.yml` |
| The role line under the name ("PhD Researcher · University College Dublin") | `_quarto.yml`, under `navbar:` `title:` |
| Colours, font and layout | `theme.scss` |
| Home page: photo, bio, the list of the other pages | `index.qmd` |
| Research page intro and headings | `research.qmd` |
| Publications and working papers | `research/papers.yml` (layout: `research/paper.ejs`) |
| Presentations | `research/presentations.yml` (layout: `research/presentation.ejs`) |
| CV page header (name, address, PDF link) | `cv.qmd` |
| CV page body | generated from `../Somboonkittichai_CV.qmd` (see below) |
| Teaching | `teaching.qmd` |
| Contact | `contact.qmd` |
| Footer on every page | `_footer.html` |
| Site icons and other `<head>` tags | `_head.html` |
| Skip link, small header adjustments, Escape closes the phone menu | `_skip-link.html` |
| Portrait photo and site icons | `images/` |
| Self-hosted font and its licence | `fonts/` (see "Font" below) |
| CV build step | `scripts/build-cv.R` |
| Photo preparation | `scripts/make-portrait.py` (see "Changing the photo") |
| Generated CV files (do not edit) | `cv/_cv-body.md`, `cv/_cv-updated.md`, `files/Somboonkittichai_CV.pdf` |

Your email address and profile links are typed by hand in three files:
`_footer.html`, `contact.qmd` and the header of `cv.qmd` (and, for the PDF,
in the CV source). When one changes, change them all. In `contact.qmd` and
`cv.qmd` the address appears three times on its line: the text shown (its
`<wbr>` lets it wrap after the `@`), the `mailto:` link, and the `aria-label`
that screen readers read out.

Text pages are plain Quarto Markdown. The few blocks such as
`::: {.opening}` (the larger first paragraph of a page) or
`::: {.contact-rows}` only set the layout; edit the text between them.
Section headings (`## ...`) are shown in small spaced capitals, so write them
in ordinary sentence case; a mixed-case abbreviation such as "PhD" would show
as "PHD" in such a heading.
`docs/` holds notes and plans and is not part of the site.

## Preview and render

Run these in this folder (Terminal, or the RStudio terminal):

```sh
quarto preview   # opens the site in a browser and refreshes as you save a page
quarto render    # builds the whole site into _site/
```

`quarto preview` does not notice changes to `research/*.yml` or the `.ejs`
templates. After saving one of them, re-save `research.qmd` (the page that
uses them), or restart preview.

`_site/` is the finished site. It is rebuilt on every render, so never edit it.

## The CV pipeline

The CV has one source: `../Somboonkittichai_CV.qmd`, in the folder above this
one. Edit that file for everything in the CV; the only exception is the page
header (see below). Every render first runs `scripts/build-cv.R`
(base R, registered as `pre-render` in `_quarto.yml`), which:

1. converts the CV into `cv/_cv-body.md`, which `cv.qmd` includes. The YAML
   header and raw LaTeX blocks are dropped, `\cvnote{...}` becomes a small
   grey note, `\cvflag{...}` reminders are removed, and headings move down
   one level;
2. writes the "Updated" date, the day the CV source was last saved, to
   `cv/_cv-updated.md`;
3. rebuilds `files/Somboonkittichai_CV.pdf` when that PDF is missing or older
   than the CV source. It renders a copy of the CV in a temporary folder, so
   nothing is ever written next to your CV. In that copy `\cvflagstrue` is
   switched to `\cvflagsfalse`, so red `\cvflag` reminders never appear in the
   public PDF (your own render of the CV still shows them). The PDF's
   "Updated" line carries the same date as the web page. This step took about
   2 seconds here.

After editing the CV, save it and run `quarto render` (or restart
`quarto preview`). The script only rewrites files whose content has changed.

Things worth knowing:

- The CV page header in `cv.qmd` (name, position, address, the email and
  ORCID line, keywords) is typed by hand, because the script drops the CV
  source's LaTeX header. When you change the header of the CV source, change
  `cv.qmd` to match.
- Problems never stop the site from building. If the CV source cannot be
  found, or the PDF render fails, the script prints a `[build-cv] WARNING`
  line and keeps the previous files. A failed PDF render prints
  `PDF build failed`, then the render log from its first error line; the
  whole log stays in `.quarto/build-cv-pdf.log`.
- It also warns when a LaTeX command is left in the CV text. The web page
  DROPS such a command together with its argument (all of
  `\textbf{Distinction}`, for example), while the PDF still shows it.
- Keep the generated files in the repository. Quarto reads the CV includes
  before the build step runs, and a build server (for example GitHub Actions)
  will not have your CV source. If they ever go missing, run
  `Rscript scripts/build-cv.R` once. Run it from this folder; started from
  another folder, it finds this one from its own location, or stops with a
  message instead of writing files in the wrong place.
- The PDF is rendered from a lone copy of the CV, so the CV must not rely on
  other files beside it (images, `.bib` files and so on).
- The PDF's internal creation date (in its file properties) is set to the
  day the CV was saved, on purpose, so that it matches the "Updated" line.
- The CV source's location is set in one line at the top of
  `scripts/build-cv.R`.

## Changing the photo

The portrait on the home page is `images/profile.jpg`, 960 x 1200 pixels
(4:5). To make it from an original photo, run this in this folder:

```sh
uv run --with pillow --with pillow-heif python scripts/make-portrait.py "IMG_3541 3.heic" images/profile.jpg 0.504 0.26 0.693
```

These are the settings used for the current photo. The script turns the
photo upright, converts it to standard web colour (sRGB; iPhones save photos
in Display P3), cuts out a 4:5 portrait, resizes it to 960 x 1200 pixels and
saves it with **no metadata**: the GPS location where the photo was taken,
the date and the phone model are all removed.

The three numbers choose the crop, each as a fraction of the photo:

| Number | Meaning |
|---|---|
| `0.504` | horizontal centre of the crop (0 = left edge, 1 = right edge) |
| `0.26` | top edge of the crop (0 = top of the photo, 1 = bottom) |
| `0.693` | width of the crop as a share of the photo's width; the height follows from the 4:5 shape |

If the crop would run off the photo, the script stops and says so.

Keep original photos out of the website folder, or at least rely on the
`*.heic` rule in `.gitignore`, which keeps iPhone originals out of the
repository. Every file a page uses is published, so only the cleaned copy
belongs in `images/`.

The image line in `index.qmd` (inside the `::: {.photo}` block) is

```markdown
![](images/profile.jpg){width="960" height="1200" fig-alt="Portrait of Kasidech Somboonkittichai"}
```

`width` and `height` must match the photo's size in pixels (the script
always makes 960 x 1200). Add `.mono` at the start of the braces
(`{.mono width="960" ...}`) to show the photo in black and white. The photo
is also the home page's link-preview image.

## Font

Every text on the site is set in Source Serif 4, served from the site
itself, so visitors' browsers never contact Google. `fonts/` holds the four
font files, `fonts/fonts.css` with their `@font-face` rules (linked through
`css:` in `_quarto.yml`), and the licence, `SourceSerif4-OFL.txt` (SIL Open
Font License), which is published with the font.

The files are variable fonts: one file holds every weight (the site uses
400, 500 and 600) and an optical-size axis, so the browser draws the large
page titles with finer detail and small text a little sturdier. One pair of
files holds the upright letters and the italics for the Latin alphabet, the
other pair the extended Latin alphabet (accented letters such as ő or ł);
é and the € sign are in the first pair. Characters outside them, Thai for
example, fall back to a system font.

Google's web copy of the font has no true small capitals or old-style
figures, so the section headings use ordinary capitals at a small size,
spaced out, and the year columns use the font's equal-width figures.

To fetch the files again: ask Google Fonts for
`https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@0,8..60,400..700;1,8..60,400..700&display=swap`
with a browser's user agent, download the `latin` and `latin-ext` woff2 files
it lists into `fonts/`, and copy those `@font-face` blocks into
`fonts/fonts.css` with the local file names.

## Adding a paper

Copy an entry in `research/papers.yml` and edit it. `section: publication`
lists it under Publications, `section: working` under Working papers. Leave a
field as `""` and it is not shown; each filled link (`doi`, `pdf`,
`preprint`, `slides`) adds a small link under the paper. To add an abstract, replace the whole
`abstract: ""` line, and the TODO comment line above it, with a block:

```yaml
  abstract: |
    First paragraph of the abstract.

    Second paragraph.
```

The paper then gets an "Abstract" link that opens and closes it (without
JavaScript, the abstract is simply shown). A PDF you want to host yourself
goes in `files/`, linked as `pdf: "files/name.pdf"`.

After saving `research/papers.yml`, re-save `research.qmd` if
`quarto preview` is running (see "Preview and render").

## Adding a presentation

Copy an item in `research/presentations.yml` to the top of the list and edit
it. The Research page shows them in the order of the file, so keep the newest
first.

After saving it, re-save `research.qmd` if `quarto preview` is running.

## Adding a tab

1. Create a page in this folder (not in a subfolder), for example
   `talks.qmd`:

```markdown
---
title: "Talks"
description: "One sentence for search engines and link previews."
---

Text of the page.

## A section heading

More text.
```

2. Add it to the tabs in `_quarto.yml`, under `navbar:` and `left:`, after
   the Contact entry. Line `- text:` up with the entry above (six spaces
   before the dash, eight before `href:`):

```yaml
      - text: Contact
        href: contact.qmd
      - text: Talks
        href: talks.qmd
```

## Switching to a white background

In `theme.scss`, find the line that starts with `$paper:` (line 7) and change
`#FCFAF6` to `#FFFFFF`. Everything else (text, rules, links) keeps its
colour.

## Still to do

- Profile links for UCD, Google Scholar, LinkedIn and Bluesky are written
  out but commented out in `_footer.html` and `contact.qmd`. Add each address
  and remove the comment marks.
- Abstracts for the papers in `research/papers.yml`.
- `site-url` in `_quarto.yml`, together with `canonical-url: true` under
  `format: html:`, at the first publish (see `docs/publishing.md`).

## Publishing

See `docs/publishing.md`.
