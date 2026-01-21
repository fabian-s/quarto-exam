# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Quarto extension** that provides an exam template for LMU Munich. It generates professional PDF exam papers (Klausuren) with:
- Cover page (Deckblatt) with student information fields and points table
- Customizable instructions page (Hinweise) via included child document
- Automatic exercise numbering via `## Aufgabe` headings
- **Auto-points tracking**: points are derived from markers (`\p`, `\hp`, `\pp`) in solution blocks
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
- `packages.tex` - LaTeX preamble: point marker commands (`\p`, `\hp`, `\pp`), auto-points display
- `deckblatt.tex` - Cover page (page 1): student fields and auto-generated points table
- `zusatzblatt.tex` - Supplementary pages at document end
- `aufgabe.lua` - Lua filter that formats `## Aufgabe` headings, counts point markers in solutions, generates points table

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
- `::: {.solution}` - Solution block (hidden in exam mode, shown in solution mode)
- `\p` - Point marker: 1 point (use inside solution blocks, works in text and math)
- `\hp` - Point marker: 0.5 points (half point)
- `\pp` - Point marker: 2 points (double point)
- `\antwortfeld{height}` - Answer box with 5mm grid (height in cm). Only shown in exam mode, hidden in solution mode.
- `\anzahlaufgaben{}` - Total number of exercises (auto-calculated)
- `\gesamtpunkte{}` - Total points (auto-calculated from markers)

**Auto-points system:**
- Points are automatically calculated by summing `\p` (1pt), `\hp` (0.5pt), `\pp` (2pt) markers **inside solution blocks only**
- Markers outside solution blocks are ignored for point calculation
- Markers work both in text mode and inside math environments
- In solution mode: markers display as red superscripts like `^[1P]`
- In exam mode: markers are invisible
- Exercise totals shown flush right on the same line as the exercise header
- Points table on cover page auto-generated from these markers

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

Question text here.

\antwortfeld{4}

::: {.solution}
**Lösung:**

First step of the solution. \p
Second step worth half a point. \hp
Final answer worth double points. \pp
Point markers also work in math: $x = y \p$
:::
```

In this example, Aufgabe 1 gets 4.5 points (1 + 0.5 + 2 + 1), displayed as "(4.5 Punkte)" flush right on the header line.

**Legacy syntax:** The old `::: {.content-hidden unless-meta="solution"}` syntax still works and is equivalent to `::: {.solution}`.

## Reference Files

The `attic/` directory contains the original LaTeX implementation:
- `_static/klausur.sty` - Original LaTeX package with full points tracking
- `klausur.tex` - Example LaTeX exam document
- `blatt-02.qmd` - Example Quarto exercise sheet with solution toggle
