# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Quarto extension** that provides an exam template for LMU Munich. It generates professional PDF exam papers (Klausuren) with:
- Cover page (Deckblatt) with student information fields and points table
- Customizable instructions page (Hinweise) via included child document
- Automatic exercise numbering via `## Aufgabe` headings
- Points tracking with `\punkte{n}` command
- Solution toggle via `-M solution:true/false`
- Supplementary pages (Zusatzblätter) for extra work space

## Rendering Commands

```bash
# Render exam sheet (solutions hidden)
quarto render template.qmd -M solution:false

# Render solution sheet (solutions visible)
quarto render template.qmd -M solution:true

# Render to specific output files
quarto render template.qmd -M solution:false -o exam.pdf
quarto render template.qmd -M solution:true -o solutions.pdf
```

Requirements: Quarto >= 1.4.0, pdfLaTeX with packages: fancyhdr, lastpage

## Architecture

The extension lives in `_extensions/exam/` and contributes a single format: `exam-pdf`.

**Extension files (`_extensions/exam/`):**
- `_extension.yml` - Extension configuration (paper size, fonts, margins, filters)
- `packages.tex` - LaTeX preamble: `\punkte` command for points, `\leerzeile` for blank lines
- `deckblatt.tex` - Cover page (page 1): student fields and auto-generated points table
- `zusatzblatt.tex` - Supplementary pages at document end
- `aufgabe.lua` - Lua filter that formats `## Aufgabe` headings with auto-numbering and generates points table

**User-provided files:**
- `hinweise.qmd` - Instructions page (page 2): exam rules. Copy and customize for each exam, include with `{{< include hinweise.qmd >}}`

**Document YAML front matter fields:**
- `semester` - e.g., "Wintersemester 2024/25"
- `veranstaltung` - Full course title (shown on cover page)
- `veranstaltung-kurz` - Short course name for page headers (optional, falls back to full name)
- `dozent` - Instructor name(s)
- `datum` - Exam date
- `dauer` - Duration in minutes
- `format: exam-pdf` - Activates this extension

**Exam content commands:**
- `## Aufgabe X` - Creates a new exercise with automatic numbering
- `\punkte{n}` - Displays points: "(n Punkte)"
- `\leerzeile[n]` - Adds blank line for student answers
- `::: {.content-hidden unless-meta="solution"}` - Conditional solution block

## Example Document Structure

```markdown
---
semester: "Wintersemester 2024/25"
veranstaltung: "Course Name"
veranstaltung-kurz: "CN"  # optional, for page headers
dozent: "Prof. Dr. Name"
datum: "15.02.2025"
dauer: 90
format: exam-pdf
---

{{< include hinweise.qmd >}}

## Aufgabe 1

Question text here. \punkte{10}

\leerzeile[5]

::: {.content-hidden unless-meta="solution"}
**Lösung:**

Solution text here.
:::
```

## Reference Files

The `attic/` directory contains the original LaTeX implementation:
- `_static/klausur.sty` - Original LaTeX package with full points tracking
- `klausur.tex` - Example LaTeX exam document
- `blatt-02.qmd` - Example Quarto exercise sheet with solution toggle
