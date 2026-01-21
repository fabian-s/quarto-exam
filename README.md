# LMU Munich Exam Template

A Quarto extension for creating professional PDF exam papers (Klausuren) for LMU Munich. Features automatic exercise numbering, points tracking from solution markers, and automatic answer field generation.

## Features

- **Cover page (Deckblatt)** with student information fields and auto-generated points table
- **Customizable instructions page (Hinweise)** via included child document
- **Auto-numbered exercises** via `##` headings (with optional titles)
- **Auto-numbered sub-exercises** via `###` headings (a, b, c...)
- **Auto-points tracking** from `\p`, `\hp`, `\pp` markers in solution blocks
- **Auto-generated answer fields** - solution blocks become grid boxes in exam mode
- **Styled solution blocks** with visual left border in solution mode
- **Solution toggle** - render exam sheet or solution sheet from same source
- **Supplementary pages (Zusatzblätter)** for extra work space

## Installation

```bash
quarto add fabian-s/quarto-exam
```

Or clone the repository and copy `_extensions/exam/` to your project.

## Usage

### Basic Document Structure

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

Question text here.

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
Solution for part a). \p \pp
:::

###

$f(\mathbf{A}) = \mathbf{A} \mathbf{B}$

::: {.solution}
Solution for part b) - answer field auto-sized. \p \pp
:::
```

### Rendering

```bash
# Exam sheet (answer grids, no solutions)
quarto render exam.qmd -M solution:false -o exam.pdf

# Solution sheet (solutions shown, no grids)
quarto render exam.qmd -M solution:true -o solutions.pdf
```

### Solution Blocks and Answer Fields

Solution blocks serve dual purpose:
- **Exam mode** (`-M solution:false`): Replaced with 5mm grid answer field
- **Solution mode** (`-M solution:true`): Displayed with styled box

**The `box` attribute:**
```markdown
::: {.solution box=4}    # 4cm answer field in exam mode
...
:::

::: {.solution}          # Auto-sized based on content
...
:::
```

If `box` is omitted, the height is auto-estimated from the solution content (~0.5cm per line, minimum 2cm).

### Exercise and Sub-Exercise Syntax

**Exercises (`##`):**
- Any `##` heading becomes an exercise, auto-numbered 1, 2, 3...
- Title is optional: `##` alone → "Aufgabe 1", `## Title` → "Aufgabe 1: Title"
- Points shown flush right as `[X Punkte]`

**Sub-exercises (`###`):**
- `###` on its own line creates a sub-exercise, auto-numbered a), b), c)...
- The paragraph following `###` becomes the question text
- Sub-exercise numbering resets with each new exercise

### Points System

Points are automatically calculated from markers inside `::: {.solution}` blocks:

| Marker | Points | Display (in solution mode) |
|--------|--------|---------------------------|
| `\p`   | 1      | ^[1P]                     |
| `\hp`  | 0.5    | ^[½P]                     |
| `\pp`  | 2      | ^[2P]                     |

- Markers work in both text and math mode
- Exercise points = sum of sub-exercise points (or direct points if no sub-exercises)
- Points table on cover page is auto-generated

### YAML Front Matter Fields

| Field | Description | Required |
|-------|-------------|----------|
| `semester` | e.g., "Wintersemester 2024/25" | Yes |
| `veranstaltung` | Full course title | Yes |
| `veranstaltung-kurz` | Short name for headers (e.g., "FMM") | No |
| `dozent` | Instructor name(s) | Yes |
| `datum` | Exam date | Yes |
| `dauer` | Duration in minutes | Yes |
| `format` | Must be `exam-pdf` | Yes |

### Commands

| Command | Description |
|---------|-------------|
| `##` or `## Title` | Creates auto-numbered exercise heading |
| `###` | Creates auto-numbered sub-exercise (a, b, c...) |
| `::: {.solution}` | Solution block with auto-sized answer field |
| `::: {.solution box=X}` | Solution block with X cm answer field |
| `\p`, `\hp`, `\pp` | Point markers (1, 0.5, 2 points) |
| `\anzahlaufgaben{}` | Total number of exercises (auto-calculated) |
| `\gesamtpunkte{}` | Total points (auto-calculated) |

### Customizing Instructions (hinweise.qmd)

Create a `hinweise.qmd` file in your project directory. This is included after the cover page and can reference auto-calculated values:

```markdown
\thispagestyle{empty}

\begin{center}
\Large\textbf{Hinweise zur Klausur}\\[0.3cm]
\rule{\textwidth}{0.4mm}
\end{center}

\vspace{0.5cm}

- Die Klausur umfasst **\anzahlaufgaben{} Aufgaben** mit insgesamt **\gesamtpunkte{} Punkten**.
- Die Bearbeitungszeit beträgt **\examdauer{} Minuten**.
- ... (your exam rules)

\vfill
\newpage
```

## File Structure

```
your-exam/
├── _extensions/exam/     # The extension (copy from this repo)
│   ├── _extension.yml
│   ├── aufgabe.lua       # Lua filter for auto-numbering and points
│   ├── packages.tex      # LaTeX preamble
│   ├── deckblatt.tex     # Cover page template
│   └── zusatzblatt.tex   # Supplementary pages
├── hinweise.qmd          # Your exam instructions (customize this)
└── exam.qmd              # Your exam document
```

## Requirements

- Quarto >= 1.4.0
- pdfLaTeX with packages: fancyhdr, lastpage, tikz, tcolorbox

## Example Output

The template generates:
1. **Page 1**: Cover page with student fields and points table
2. **Page 2**: Exam instructions (from hinweise.qmd)
3. **Pages 3+**: Exam questions with answer grids (exam) or styled solutions (solution sheet)
4. **Final pages**: Supplementary pages for additional work

## Credits

Based on the [Monash Exam Template](https://github.com/quarto-monash/exam) by Rob J Hyndman.

Adapted for LMU Munich by Claude on behalf of Fabian Scheipl.

## License

CC0 - Public Domain
