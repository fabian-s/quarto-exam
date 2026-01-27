# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Quarto extension** that provides an exam template for LMU Munich. It generates professional PDF exam papers (Klausuren) with:
- Cover page (Deckblatt) with student information fields and points table
- Customizable instructions page (Hinweise) via included child document
- **Auto-numbered exercises** via `##` headings (with optional titles)
- **Auto-numbered sub-exercises** via `###` headings (a, b, c...)
- **Auto-points tracking**: points derived from markers (`\p`, `\hp`, `\pp`) in solution blocks
- **Auto-generated answer fields**: solution blocks automatically become answer boxes in exam mode
- **Grid or blank answer fields**: `grid-paper: true/false` controls whether answer boxes have 5mm grid
- Solution toggle via `-M solution:true/false`
- **Language support**: German (`exam-lang: de`) or English (`exam-lang: en`)
- **Configurable extra pages**: `extra-pages: N` for additional work space (with matching grid style)

## Rendering Commands

```bash
# Render exam sheet (solutions hidden, answer grids shown)
quarto render template.qmd -M solution:false

# Render solution sheet (solutions visible)
quarto render template.qmd -M solution:true

# Render to specific output files
quarto render template.qmd -M solution:false -o exam.pdf
quarto render template.qmd -M solution:true -o solutions.pdf

# Render with blank answer boxes (no grid)
quarto render template.qmd -M solution:false -M grid-paper:false -o exam.pdf

# Render English exam
quarto render template.qmd -M solution:false -M exam-lang:en -o exam-en.pdf

# Render without extra pages
quarto render template.qmd -M solution:false -M extra-pages:0 -o exam.pdf
```

Requirements: Quarto >= 1.4.0, pdfLaTeX with packages: fancyhdr, lastpage, tcolorbox

## Architecture

The extension lives in `_extensions/exam/` and contributes a single format: `exam-pdf`.

**Extension files (`_extensions/exam/`):**
- `_extension.yml` - Extension configuration (paper size, fonts, margins, filters)
- `packages.tex` - LaTeX preamble: point marker commands (`\p`, `\hp`, `\pp`), answer field, solution box styling
- `deckblatt.tex` - German cover page (page 1): student fields and auto-generated points table
- `coverpage.tex` - English cover page (page 1): student fields and auto-generated points table
- `aufgabe.lua` - Lua filter that auto-numbers `##`/`###` headings, counts point markers in solutions, generates points table, handles answer fields, inserts coverpage, generates extra pages

**User-provided files:**
- `hinweise.qmd` - German instructions page (page 2): exam rules
- `instructions.qmd` - English instructions page (page 2): exam rules
- Include with `{{< include hinweise.qmd >}}` or `{{< include instructions.qmd >}}`

**Document YAML front matter fields:**

| Field | Description | Default |
|-------|-------------|---------|
| `semester` | e.g., "Winter 2024/25" | required |
| `course` | Full course title (shown on cover page) | required |
| `course-short` | Short course name for page headers | falls back to `course` |
| `instructor` | Instructor name(s) | required |
| `exam-date` | Exam date (use any format, e.g., "15.02.2025") | required |
| `duration` | Duration in minutes | required |
| `exam-lang` | Language: `de` or `en` | `de` |
| `grid-paper` | Grid lines in answer fields and extra pages | `true` |
| `extra-pages` | Number of extra pages at end | `2` |
| `answerfields` | Show answer fields in exam mode | `true` |
| `format` | Must be `exam-pdf` | required |

**Exam content commands:**
- `##` or `## Title` - Creates a new exercise, auto-numbered 1, 2, 3...
- `###` - Creates a new sub-exercise, auto-numbered a), b), c)... (resets with each exercise)
- `::: {.solution}` - Solution block with auto-sized answer field in exam mode
- `::: {.solution box=X}` - Solution block with X cm answer field in exam mode
- `\p` - Point marker: 1 point (use inside solution blocks, works in text and math)
- `\hp` - Point marker: 0.5 points (half point)
- `\pp` - Point marker: 2 points (double point)
- `\examexercisecount{}` - Total number of exercises (auto-calculated)
- `\examtotalpoints{}` - Total points (auto-calculated from markers)

## Solution Blocks and Answer Fields

Solution blocks serve dual purpose:
- **In solution mode** (`-M solution:true`): Display solution with styled box (gray left border)
- **In exam mode** (`-M solution:false`): Display answer field box

**Syntax:**
```markdown
::: {.solution box=4}
Solution content here...
:::
```

**The `box` attribute:**
- `box=X` - Creates answer field of X cm height in exam mode
- If omitted, height is auto-estimated from solution content (~0.5cm per line)

**Grid vs Blank:**
- `grid-paper: true` (default) - Answer fields have 5mm grid lines
- `grid-paper: false` - Answer fields are blank (just grey border)
- Extra pages at end match the grid setting

**Auto-estimation:**
- Counts characters and blocks in solution
- Roughly 80 characters per line, 0.5cm per line
- Minimum 2cm, rounded to nearest 0.5cm
- Works well for typical solutions; use explicit `box=X` for precise control
- Answer fields automatically break across pages if too tall to fit

**Disabling answer fields:**
- Set `answerfields: false` in front matter to omit all answer boxes in exam mode
- Solution blocks produce no output when disabled (no box, no space)
- Useful for exams where students answer on separate paper

## Exercise and Sub-Exercise Syntax

**Exercise headers (`##`):**
- Any `##` heading becomes an exercise, auto-numbered 1, 2, 3...
- Title is optional:
  - `## ` or `##` alone → "Aufgabe 1" / "Exercise 1"
  - `## Some Title` → "Aufgabe 1: Some Title" / "Exercise 1: Some Title"
- Points shown flush right as `[X Punkte]` / `[X Points]` in normalsize font

**Sub-exercise headers (`###`):**
- `###` on its own line denotes a sub-exercise, auto-numbered a), b), c)...
- The paragraph following `###` becomes the question text
- Format: `a) question text [X Punkte]` / `a) question text [X Points]`
- Sub-exercise numbering resets with each new exercise

**Point calculation:**
- Exercise total = sum of all sub-exercise points (or direct points if no sub-exercises)
- Sub-exercise points = sum of `\p`, `\hp`, `\pp` markers in its solution blocks
- Markers outside solution blocks are ignored for point calculation
- Markers work both in text mode and inside math environments
- In solution mode: markers display as red superscripts like `^[1P]`
- In exam mode: markers are invisible
- Points table on cover page auto-generated from exercise totals

## Language Support

Set `exam-lang: en` for English or `exam-lang: de` (default) for German.

**Affects:**
- Cover page (deckblatt.tex vs coverpage.tex)
- Exercise labels ("Aufgabe" vs "Exercise")
- Points labels ("Punkte" vs "Points")
- Points table headers
- Page header/footer text
- Extra page text

## LaTeX Macro Reference

| Macro | Description |
|-------|-------------|
| `\examsemester` | Semester value |
| `\examcourse` | Full course name |
| `\examcourseshort` | Short course name |
| `\examinstructor` | Instructor name |
| `\examdate` | Exam date |
| `\examduration` | Duration in minutes |
| `\examexercisecount` | Number of exercises |
| `\examtotalpoints` | Total points |
| `\exampointstable` | Points table |
| `\examanswerfield{X}` | Answer field of X cm height |
| `\exampoints{X}` | Points display "(X Punkte)" |

## Example Document Structure

```markdown
---
semester: "Winter 2024/25"
course: "Advanced Statistical Methods"
course-short: "ASM"
instructor: "Prof. Dr. Name"
exam-date: "15.02.2025"
duration: 90
exam-lang: en
grid-paper: true
extra-pages: 2
format: exam-pdf
---

{{< include instructions.qmd >}}

## Maximum Likelihood Estimator

Question text for exercise without sub-exercises.

::: {.solution box=4}
**Solution:**

First step of the solution. \p
Second step worth half a point. \hp
Final answer worth double points. \pp
:::

## Condition Numbers

Introduction text for exercise with sub-exercises.

###

$f(\mathbf{A}) = \mathbf{A} + \mathbf{B}$

::: {.solution box=2.5}
**Solution:**

Solution for part a). \p \pp
:::

###

$f(\mathbf{A}) = \mathbf{A} \mathbf{B}$

::: {.solution}
**Solution:**

Solution for part b) - height auto-estimated. \p \pp
:::
```

**Renders as (exam mode, English):**
```
Exercise 1: Maximum Likelihood Estimator                  [X Points]
Question text...
[4cm answer box with grid]

Exercise 2: Condition Numbers                             [Y Points]
Introduction text...

a) f(A) = A + B                                           [3 Points]
[2.5cm answer box with grid]

b) f(A) = A B                                             [3 Points]
[auto-sized answer box with grid]
```

## Reference Files

The `attic/` directory contains the original LaTeX implementation:
- `_static/klausur.sty` - Original LaTeX package with full points tracking
- `klausur.tex` - Example LaTeX exam document
- `blatt-02.qmd` - Example Quarto exercise sheet with solution toggle
