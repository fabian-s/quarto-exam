# LMU Munich Exam Template

A Quarto extension for creating professional PDF exam papers (Klausuren) for LMU Munich. Features automatic points tracking, conditional solution display, and grid-lined answer boxes.

## Features

- **Cover page (Deckblatt)** with student information fields and auto-generated points table
- **Customizable instructions page (Hinweise)** via included child document
- **Automatic exercise numbering** via `## Aufgabe` headings
- **Points tracking** with `\punkte{n}` - automatically summed per exercise and in total
- **Answer boxes** with 5mm grid pattern (`\antwortfeld{height}`)
- **Solution toggle** - render exam sheet or solution sheet from same source
- **Supplementary pages (Zusatzblätter)** for extra work space

## Installation

```bash
quarto add fabianegli/quarto-exam
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

## Aufgabe 1

Question text here. \punkte{10}

\antwortfeld{4}

::: {.content-hidden unless-meta="solution"}
**Lösung:**

Solution text here.
:::

## Aufgabe 2

Another question. \punkte{8}

\antwortfeld{3}

::: {.content-hidden unless-meta="solution"}
**Lösung:**

Another solution.
:::
```

### Rendering

```bash
# Exam sheet (no solutions, with answer grids)
quarto render exam.qmd -M solution:false -o exam.pdf

# Solution sheet (with solutions, no grids)
quarto render exam.qmd -M solution:true -o solutions.pdf
```

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
| `## Aufgabe X` | Creates numbered exercise heading |
| `\punkte{n}` | Displays "(n Punkte)" right-aligned |
| `\antwortfeld{h}` | Answer box with 5mm grid, height in cm (exam only) |
| `\anzahlaufgaben{}` | Total number of exercises (auto-calculated) |
| `\gesamtpunkte{}` | Total points (auto-calculated) |
| `\examdauer{}` | Exam duration from YAML |
| `\examsemester{}` | Semester from YAML |
| `\examveranstaltung{}` | Course name from YAML |

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
│   ├── aufgabe.lua       # Lua filter for points tracking
│   ├── packages.tex      # LaTeX preamble
│   ├── deckblatt.tex     # Cover page template
│   └── zusatzblatt.tex   # Supplementary pages
├── hinweise.qmd          # Your exam instructions (customize this)
└── exam.qmd              # Your exam document
```

## Requirements

- Quarto >= 1.4.0
- pdfLaTeX with packages: fancyhdr, lastpage, tikz

## Example Output

The template generates:
1. **Page 1**: Cover page with student fields and points table
2. **Page 2**: Exam instructions (from hinweise.qmd)
3. **Pages 3+**: Exam questions with answer grids (exam) or solutions (solution sheet)
4. **Final pages**: Supplementary pages for additional work

## Credits

Based on the [Monash Exam Template](https://github.com/quarto-monash/exam) by Rob J Hyndman.

Adapted for LMU Munich by Fabian Scheipl with assistance from Claude.

## License

CC0 - Public Domain
