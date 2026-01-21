# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Quarto extension** that provides an exam template for LMU Munich. It generates professional PDF exam papers (Klausuren) with:
- Cover page (Deckblatt) with student information fields and points table
- Customizable instructions page (Hinweise) via included child document
- **Auto-numbered exercises** via `##` headings (with optional titles)
- **Auto-numbered sub-exercises** via `###` headings (a, b, c...)
- **Auto-points tracking**: points derived from markers (`\p`, `\hp`, `\pp`) in solution blocks
- **Auto-generated answer fields**: solution blocks automatically become answer grids in exam mode
- Solution toggle via `-M solution:true/false`
- Supplementary pages (Zusatzblätter) for extra work space

## Rendering Commands

```bash
# Render exam sheet (solutions hidden, answer grids shown)
quarto render template.qmd -M solution:false

# Render solution sheet (solutions visible)
quarto render template.qmd -M solution:true

# Render to specific output files
quarto render template.qmd -M solution:false -o exam.pdf
quarto render template.qmd -M solution:true -o solutions.pdf
```

Requirements: Quarto >= 1.4.0, pdfLaTeX with packages: fancyhdr, lastpage, tcolorbox

## Architecture

The extension lives in `_extensions/exam/` and contributes a single format: `exam-pdf`.

**Extension files (`_extensions/exam/`):**
- `_extension.yml` - Extension configuration (paper size, fonts, margins, filters)
- `packages.tex` - LaTeX preamble: point marker commands (`\p`, `\hp`, `\pp`), answer field, solution box styling
- `deckblatt.tex` - Cover page (page 1): student fields and auto-generated points table
- `zusatzblatt.tex` - Supplementary pages at document end
- `aufgabe.lua` - Lua filter that auto-numbers `##`/`###` headings, counts point markers in solutions, generates points table, handles answer fields

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
- `##` or `## Title` - Creates a new exercise, auto-numbered 1, 2, 3...
- `###` - Creates a new sub-exercise, auto-numbered a), b), c)... (resets with each exercise)
- `::: {.solution}` - Solution block with auto-sized answer field in exam mode
- `::: {.solution box=X}` - Solution block with X cm answer field in exam mode
- `\p` - Point marker: 1 point (use inside solution blocks, works in text and math)
- `\hp` - Point marker: 0.5 points (half point)
- `\pp` - Point marker: 2 points (double point)
- `\anzahlaufgaben{}` - Total number of exercises (auto-calculated)
- `\gesamtpunkte{}` - Total points (auto-calculated from markers)

## Solution Blocks and Answer Fields

Solution blocks serve dual purpose:
- **In solution mode** (`-M solution:true`): Display solution with styled box (gray left border)
- **In exam mode** (`-M solution:false`): Display answer field with 5mm grid

**Syntax:**
```markdown
::: {.solution box=4}
Solution content here...
:::
```

**The `box` attribute:**
- `box=X` - Creates answer field of X cm height in exam mode
- If omitted, height is auto-estimated from solution content (~0.5cm per line)

**Auto-estimation:**
- Counts characters and blocks in solution
- Roughly 80 characters per line, 0.5cm per line
- Minimum 2cm, rounded to nearest 0.5cm
- Works well for typical solutions; use explicit `box=X` for precise control

## Exercise and Sub-Exercise Syntax

**Exercise headers (`##`):**
- Any `##` heading becomes an exercise, auto-numbered 1, 2, 3...
- Title is optional:
  - `## ` or `##` alone → "Aufgabe 1"
  - `## Some Title` → "Aufgabe 1: Some Title"
- Points shown flush right as `[X Punkte]` in normalsize font

**Sub-exercise headers (`###`):**
- `###` on its own line denotes a sub-exercise, auto-numbered a), b), c)...
- The paragraph following `###` becomes the question text
- Format: `a) question text [X Punkte]`
- Sub-exercise numbering resets with each new exercise

**Point calculation:**
- Exercise total = sum of all sub-exercise points (or direct points if no sub-exercises)
- Sub-exercise points = sum of `\p`, `\hp`, `\pp` markers in its solution blocks
- Markers outside solution blocks are ignored for point calculation
- Markers work both in text mode and inside math environments
- In solution mode: markers display as red superscripts like `^[1P]`
- In exam mode: markers are invisible
- Points table on cover page auto-generated from exercise totals

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

## Maximum-Likelihood-Schätzer

Question text for exercise without sub-exercises.

::: {.solution box=4}
**Lösung:**

First step of the solution. \p
Second step worth half a point. \hp
Final answer worth double points. \pp
:::

## Konditionszahlen

Introduction text for exercise with sub-exercises.

###

$f(\mathbf{A}) = \mathbf{A} + \mathbf{B}$

::: {.solution box=2.5}
**Lösung:**

Solution for part a). \p \pp
:::

###

$f(\mathbf{A}) = \mathbf{A} \mathbf{B}$

::: {.solution}
**Lösung:**

Solution for part b) - height auto-estimated. \p \pp
:::
```

**Renders as (exam mode):**
```
Aufgabe 1: Maximum-Likelihood-Schätzer                    [X Punkte]
Question text...
[4cm answer grid]

Aufgabe 2: Konditionszahlen                               [Y Punkte]
Introduction text...

a) f(A) = A + B                                           [3 Punkte]
[2.5cm answer grid]

b) f(A) = A B                                             [3 Punkte]
[auto-sized answer grid]
```

## Reference Files

The `attic/` directory contains the original LaTeX implementation:
- `_static/klausur.sty` - Original LaTeX package with full points tracking
- `klausur.tex` - Example LaTeX exam document
- `blatt-02.qmd` - Example Quarto exercise sheet with solution toggle
