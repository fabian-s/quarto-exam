-- aufgabe.lua - Lua filter for Exam template
-- Handles exercise header formatting, metadata injection, and auto-points tracking
-- Supports auto-numbered exercises (##) and sub-exercises (###)

-- Point values for marker commands
local point_values = {
  ["\\p"] = 1,
  ["\\hp"] = 0.5,
  ["\\pp"] = 2,
}

-- Language-specific strings
local lang_strings = {
  de = {
    exercise = "Aufgabe",
    points = "Punkte",
    points_abbrev = "P",  -- Abbreviated form for sub-exercises
    points_table_possible = "mögliche Punkte",
    points_table_achieved = "erreichte Punkte",
    points_table_sum = "Summe",
    points_table_none = "(Keine Punkte definiert)",
    header_left = "Klausur %s --- %s",
    header_right = "Name:",
    footer_page = "Seite %s von %s",
    extra_page_title = "Zusatzblatt",
    extra_page_reminder = "Name und Matrikelnummer nicht vergessen!",
  },
  en = {
    exercise = "Exercise",
    points = "Points",
    points_abbrev = "P",  -- Abbreviated form for sub-exercises
    points_table_possible = "possible points",
    points_table_achieved = "points achieved",
    points_table_sum = "Total",
    points_table_none = "(No points defined)",
    header_left = "Exam %s --- %s",
    header_right = "Name:",
    footer_page = "Page %s of %s",
    extra_page_title = "Extra Page",
    extra_page_reminder = "Don't forget your name and student ID!",
  }
}

-- Helper to get the directory containing this filter script
local function get_filter_directory()
  local script_path = PANDOC_SCRIPT_FILE
  if script_path then
    return script_path:match("(.*/)" ) or script_path:match("(.*\\)") or "./"
  end
  return "./"
end

-- Helper to read a file's contents
local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

-- Read coverpage template based on language
local function read_coverpage(lang)
  local filter_dir = get_filter_directory()
  local filename = (lang == "en") and "coverpage.tex" or "deckblatt.tex"
  return read_file(filter_dir .. filename)
end

-- Helper to get metadata value as string
local function meta_to_string(meta_value)
  if meta_value == nil then
    return ""
  elseif type(meta_value) == "string" then
    return meta_value
  elseif type(meta_value) == "boolean" then
    return tostring(meta_value)
  elseif meta_value.t == "MetaInlines" then
    return pandoc.utils.stringify(meta_value)
  elseif meta_value.t == "MetaString" then
    return meta_value.text or pandoc.utils.stringify(meta_value)
  else
    return pandoc.utils.stringify(meta_value)
  end
end

-- Helper to get metadata as boolean with default
local function meta_to_bool(meta_value, default)
  if meta_value == nil then
    return default
  end
  if type(meta_value) == "boolean" then
    return meta_value
  end
  local str = meta_to_string(meta_value)
  if str == "true" then return true end
  if str == "false" then return false end
  return default
end

-- Helper to get metadata as number with default
local function meta_to_number(meta_value, default)
  if meta_value == nil then
    return default
  end
  local str = meta_to_string(meta_value)
  local num = tonumber(str)
  return num or default
end

-- Format points for display (handles decimals nicely)
local function format_points(pts)
  if pts == math.floor(pts) then
    return tostring(math.floor(pts))
  else
    return string.format("%.1f", pts)
  end
end

-- Convert number to letter (1=a, 2=b, etc.)
local function num_to_letter(n)
  return string.char(string.byte('a') + n - 1)
end

-- Generate points table LaTeX
local function generate_points_table(exercise_points, lang)
  local strings = lang_strings[lang] or lang_strings["de"]
  local rows = {}
  local total = 0

  -- Sort exercises by number
  local exercise_nums = {}
  for num, _ in pairs(exercise_points) do
    table.insert(exercise_nums, num)
  end
  table.sort(exercise_nums)

  -- Build table rows
  for _, num in ipairs(exercise_nums) do
    local pts = exercise_points[num]
    total = total + pts
    table.insert(rows, string.format("  %s %d & %s & \\\\", strings.exercise, num, format_points(pts)))
  end

  if #rows == 0 then
    return nil, 0  -- No points found, use default table
  end

  -- Build complete table
  local table_latex = string.format([[
\begin{tabular}{|l|c|c|}
  \hline
  & %s & %s \\
  \hline
  \hline
]], strings.points_table_possible, strings.points_table_achieved) .. table.concat(rows, "\n  \\hline\n") .. string.format([[

  \hline
  \textbf{%s} & \textbf{%s} & \\
  \hline
\end{tabular}]], strings.points_table_sum, format_points(total))

  return table_latex, total
end

-- Check if a Div is a solution block
local function is_solution_div(div)
  return div.classes:includes("solution")
end

-- Count point markers in text (LaTeX raw content)
local function count_points_in_text(text)
  local points = 0
  -- Count \p markers (1 point)
  -- Match \p followed by non-letter (end of command), but not \pp or \punkte
  for _ in text:gmatch("\\p[^a-zA-Z]") do
    points = points + point_values["\\p"]
  end
  -- Also match \p at end of string
  if text:match("\\p$") then
    points = points + point_values["\\p"]
  end
  -- Count \hp markers (half point)
  for _ in text:gmatch("\\hp[^a-zA-Z]") do
    points = points + point_values["\\hp"]
  end
  if text:match("\\hp$") then
    points = points + point_values["\\hp"]
  end
  -- Count \pp markers (double point)
  for _ in text:gmatch("\\pp[^a-zA-Z]") do
    points = points + point_values["\\pp"]
  end
  if text:match("\\pp$") then
    points = points + point_values["\\pp"]
  end
  return points
end

-- Forward declaration for mutual recursion
local count_points_in_inlines
local count_points_in_blocks

-- Count points in inline elements
count_points_in_inlines = function(inlines)
  local points = 0
  for _, el in ipairs(inlines) do
    if el.t == "RawInline" and (el.format == "tex" or el.format == "latex") then
      points = points + count_points_in_text(el.text)
    elseif el.t == "Math" then
      -- Math elements store their content as a string in el.text
      points = points + count_points_in_text(el.text)
    elseif el.content then
      -- Some inline elements have nested content (e.g., Emph, Strong)
      points = points + count_points_in_inlines(el.content)
    end
  end
  return points
end

-- Count points in a list of blocks recursively
count_points_in_blocks = function(blocks)
  local points = 0
  for _, block in ipairs(blocks) do
    if block.t == "RawBlock" and (block.format == "tex" or block.format == "latex") then
      points = points + count_points_in_text(block.text)
    elseif block.t == "Para" or block.t == "Plain" then
      points = points + count_points_in_inlines(block.content)
    elseif block.t == "Div" then
      points = points + count_points_in_blocks(block.content)
    elseif block.t == "BlockQuote" then
      points = points + count_points_in_blocks(block.content)
    elseif block.t == "BulletList" or block.t == "OrderedList" then
      for _, item in ipairs(block.content) do
        points = points + count_points_in_blocks(item)
      end
    elseif block.t == "DefinitionList" then
      for _, item in ipairs(block.content) do
        points = points + count_points_in_inlines(item[1])  -- term
        for _, def in ipairs(item[2]) do  -- definitions
          points = points + count_points_in_blocks(def)
        end
      end
    elseif block.t == "Header" then
      points = points + count_points_in_inlines(block.content)
    elseif block.t == "Table" then
      -- Tables have complex structure, walk through cells
      if block.head then
        for _, row in ipairs(block.head[2]) do
          for _, cell in ipairs(row[2]) do
            points = points + count_points_in_blocks(cell[5])
          end
        end
      end
      for _, body in ipairs(block.bodies or {}) do
        for _, row in ipairs(body[3] or {}) do
          for _, cell in ipairs(row[2]) do
            points = points + count_points_in_blocks(cell[5])
          end
        end
        for _, row in ipairs(body[4] or {}) do
          for _, cell in ipairs(row[2]) do
            points = points + count_points_in_blocks(cell[5])
          end
        end
      end
    end
  end
  return points
end

-- Count points in a Div (solution block)
local function count_points_in_div(div)
  return count_points_in_blocks(div.content)
end

-- Estimate height (in cm) needed for content
-- This is a rough estimate: ~0.5cm per line, ~80 chars per line
local function estimate_content_height(blocks)
  local total_chars = 0
  local extra_lines = 0

  for _, block in ipairs(blocks) do
    if block.t == "Para" or block.t == "Plain" then
      local text = pandoc.utils.stringify(block.content)
      total_chars = total_chars + #text
      extra_lines = extra_lines + 1  -- paragraph spacing
    elseif block.t == "Math" or (block.t == "Para" and block.content[1] and block.content[1].t == "Math") then
      extra_lines = extra_lines + 2  -- display math takes more space
    elseif block.t == "BulletList" or block.t == "OrderedList" then
      for _, item in ipairs(block.content) do
        local text = pandoc.utils.stringify(item)
        total_chars = total_chars + #text
        extra_lines = extra_lines + 0.5  -- list item spacing
      end
    elseif block.t == "RawBlock" then
      -- LaTeX blocks - estimate based on content
      extra_lines = extra_lines + 2
    elseif block.t == "Div" then
      -- Nested div - recurse
      local nested = estimate_content_height(block.content)
      extra_lines = extra_lines + nested / 0.5
    else
      -- Other blocks
      local text = pandoc.utils.stringify(block)
      total_chars = total_chars + #text
    end
  end

  -- ~80 chars per line, ~0.5cm per line
  local text_lines = total_chars / 80
  local total_lines = text_lines + extra_lines

  -- Convert to cm, minimum 2cm
  local height = math.max(2, total_lines * 0.5)
  -- Round to nearest 0.5
  height = math.floor(height * 2 + 0.5) / 2

  return height
end

-- Generate extra pages LaTeX (with optional grid)
local function generate_extra_pages(num_pages, lang, use_grid)
  local strings = lang_strings[lang] or lang_strings["de"]
  local pages = {}

  for i = 1, num_pages do
    if use_grid then
      -- Grid version: full-page grid with title
      table.insert(pages, string.format([[
\clearpage
\thispagestyle{fancy}
{\bfseries\Large %s}\par\vspace{3mm}
\begin{tcolorbox}[
  enhanced,
  colback=white,
  colframe=gray!40,
  boxrule=0.4pt,
  arc=0pt,
  outer arc=0pt,
  left=0pt, right=0pt, top=0pt, bottom=0pt,
  boxsep=0pt,
  height fill,
  underlay={
    \begin{tcbclipinterior}
      \draw[step=5mm, gray!40, thin] (interior.south west) grid (interior.north east);
    \end{tcbclipinterior}
  },
]
\mbox{}
\end{tcolorbox}
]], strings.extra_page_title))
    else
      -- Blank version: just title
      table.insert(pages, string.format([[
\clearpage
\thispagestyle{fancy}
{\bfseries\Large %s}
]], strings.extra_page_title))
    end
  end

  return table.concat(pages, "\n")
end

-- Main filter function - processes entire document
function Pandoc(doc)
  -- Get exam language (default: de)
  local exam_lang = meta_to_string(doc.meta["exam-lang"])
  if exam_lang == "" then
    exam_lang = "de"
  end
  local strings = lang_strings[exam_lang] or lang_strings["de"]

  -- Get extra pages count (default: 2)
  local extra_pages = meta_to_number(doc.meta["extra-pages"], 2)

  -- Get grid setting (default: true)
  local use_grid = meta_to_bool(doc.meta["grid-paper"], true)

  -- Check solution mode early (needed for div processing)
  local is_solution_mode = meta_to_bool(doc.meta["solution"], false)

  -- Check answerfields setting (default: true)
  local show_answerfields = meta_to_bool(doc.meta["answerfields"], true)

  -- State tracking
  local exercise_count = 0
  local current_exercise = 0
  local current_subexercise = 0  -- 0 means no sub-exercise active

  -- Data structures for points
  local exercise_points = {}           -- Total points per exercise
  local subexercise_points = {}        -- Points per sub-exercise: subexercise_points[ex][sub] = pts
  local has_subexercises = {}          -- Track which exercises have sub-exercises

  -- Track positions for formatting
  local exercise_header_indices = {}   -- block index -> exercise number
  local subexercise_indices = {}       -- block index -> {exercise, subexercise}
  local subexercise_first_block_indices = {}  -- block index -> {exercise, subexercise} for the first block after ###

  -- First pass: identify exercises, sub-exercises, and count points
  local new_blocks = {}
  local pending_subexercise = nil  -- Track if we just saw a ### header

  for i, block in ipairs(doc.blocks) do
    -- Check if this is an exercise header (##)
    if block.t == "Header" and block.level == 2 then
      exercise_count = exercise_count + 1
      current_exercise = exercise_count
      current_subexercise = 0  -- Reset sub-exercise counter
      exercise_points[current_exercise] = 0
      subexercise_points[current_exercise] = {}
      has_subexercises[current_exercise] = false
      pending_subexercise = nil

      -- Extract title (everything in the header content)
      local title = pandoc.utils.stringify(block.content)
      title = title:match("^%s*(.-)%s*$") or ""  -- Trim whitespace

      -- Store original title for later formatting
      block.attributes["exam-title"] = title

      table.insert(new_blocks, block)
      exercise_header_indices[#new_blocks] = current_exercise
      goto continue
    end

    -- Check if this is a sub-exercise header (###)
    if block.t == "Header" and block.level == 3 then
      if current_exercise > 0 then
        current_subexercise = current_subexercise + 1
        has_subexercises[current_exercise] = true
        subexercise_points[current_exercise][current_subexercise] = 0

        -- Mark that we're expecting a paragraph to follow this header
        pending_subexercise = {current_exercise, current_subexercise}

        -- Store the header position (we'll remove it later)
        table.insert(new_blocks, block)
        subexercise_indices[#new_blocks] = {current_exercise, current_subexercise}
      else
        table.insert(new_blocks, block)
      end
      goto continue
    end

    -- Check if this is the first block following a ### header
    if pending_subexercise then
      -- Record this block (whatever type) as the sub-exercise start
      subexercise_first_block_indices[#new_blocks + 1] = pending_subexercise
      pending_subexercise = nil
      table.insert(new_blocks, block)
      goto continue
    end

    -- Transform .solution divs and handle answer fields
    if block.t == "Div" then
      local is_solution = block.classes:includes("solution") or is_solution_div(block)

      -- Count points in solution divs (always, regardless of mode)
      if is_solution and current_exercise > 0 then
        local pts = count_points_in_div(block)
        if current_subexercise > 0 then
          -- Add points to current sub-exercise
          subexercise_points[current_exercise][current_subexercise] =
            subexercise_points[current_exercise][current_subexercise] + pts
        else
          -- Add points directly to exercise (no sub-exercises)
          exercise_points[current_exercise] = exercise_points[current_exercise] + pts
        end
      end

      -- Handle solution divs based on mode
      if is_solution then
        local box_attr = block.attributes["box"]

        if is_solution_mode then
          -- Solution mode: show solution with tcolorbox styling
          -- Remove the box attribute so it doesn't appear in output
          block.attributes["box"] = nil

          local new_content = {
            pandoc.RawBlock("latex", "\\begin{solutionbox}")
          }
          for _, el in ipairs(block.content) do
            table.insert(new_content, el)
          end
          table.insert(new_content, pandoc.RawBlock("latex", "\\end{solutionbox}"))
          block.content = new_content

          -- Transform to content-hidden for Quarto (will be shown because solution:true)
          block.classes = pandoc.List({"content-hidden"})
          block.attributes["unless-meta"] = "solution"
        else
          -- Exam mode: replace solution with answer field (if enabled)
          if show_answerfields then
            local height
            if box_attr then
              -- Use specified height
              height = box_attr
            else
              -- Estimate height from content
              height = estimate_content_height(block.content)
            end

            -- Replace div content with examanswerfield
            block.content = {
              pandoc.RawBlock("latex", string.format("\\examanswerfield{%s}", height))
            }
            -- Remove classes and attributes - this is now just an answer field
            block.classes = pandoc.List({})
            block.attributes = {}
          else
            -- answerfields disabled: skip this block entirely (no output)
            goto continue
          end
        end
      end
    end

    table.insert(new_blocks, block)
    ::continue::
  end

  -- Calculate total exercise points from sub-exercises
  for ex_num, has_subs in pairs(has_subexercises) do
    if has_subs then
      local total = 0
      for _, pts in pairs(subexercise_points[ex_num]) do
        total = total + pts
      end
      exercise_points[ex_num] = total
    end
  end

  -- Second pass: format headers with points
  local final_blocks = {}
  local skip_next = false

  for i, block in ipairs(new_blocks) do
    if skip_next then
      skip_next = false
      goto continue2
    end

    -- Format exercise headers
    local ex_num = exercise_header_indices[i]
    if ex_num then
      local title = block.attributes["exam-title"] or ""
      block.attributes["exam-title"] = nil  -- Clean up

      -- Create header text (language-aware)
      local header_text
      if title ~= "" then
        header_text = string.format("%s %d: %s", strings.exercise, ex_num, title)
      else
        header_text = string.format("%s %d", strings.exercise, ex_num)
      end

      -- Add points (normalsize, flush right)
      local pts = exercise_points[ex_num] or 0
      local points_str = ""
      if pts > 0 then
        points_str = string.format("{\\normalsize\\hfill [%s %s]}", format_points(pts), strings.points)
      end

      block.content = {
        pandoc.Str(header_text),
        pandoc.RawInline("latex", points_str)
      }
      table.insert(final_blocks, block)
      goto continue2
    end

    -- Handle sub-exercise headers (### - to be removed)
    local sub_info = subexercise_indices[i]
    if sub_info then
      -- Don't add the ### header to output, just skip it
      -- The following paragraph will be formatted with the label
      goto continue2
    end

    -- Format sub-exercise first blocks (add "a) [X P]" prefix)
    local sub_block_info = subexercise_first_block_indices[i]
    if sub_block_info then
      local ex = sub_block_info[1]
      local sub = sub_block_info[2]
      local pts = subexercise_points[ex][sub] or 0
      local letter = num_to_letter(sub)

      -- Build label with points at the beginning: "a) [X P] "
      local points_str = ""
      if pts > 0 then
        points_str = string.format("[%s %s] ", format_points(pts), strings.points_abbrev)
      end

      if block.t == "Para" or block.t == "Plain" then
        -- Inline the label at start of paragraph (existing behavior)
        local label = pandoc.RawInline("latex", string.format("\\textbf{%s)} %s", letter, points_str))
        table.insert(block.content, 1, label)
        table.insert(final_blocks, block)
      else
        -- Insert label as separate paragraph before the block
        local label_para = pandoc.Para({
          pandoc.RawInline("latex", string.format("\\textbf{%s)} %s", letter, points_str))
        })
        table.insert(final_blocks, label_para)
        table.insert(final_blocks, block)
      end
      goto continue2
    end

    -- Regular block, just add it
    table.insert(final_blocks, block)
    ::continue2::
  end

  doc.blocks = final_blocks

  -- Get metadata values (English YAML keys only)
  local semester = meta_to_string(doc.meta.semester)
  local course = meta_to_string(doc.meta.course)
  local course_short = meta_to_string(doc.meta["course-short"])
  if course_short == "" then
    course_short = course  -- Fall back to full name
  end
  local instructor = meta_to_string(doc.meta.instructor)
  local exam_date = meta_to_string(doc.meta["exam-date"])
  local duration = meta_to_string(doc.meta.duration)

  -- Set solution and grid flags for LaTeX
  local solution_flag = is_solution_mode and "\\solutiontrue" or "\\solutionfalse"
  local grid_flag = use_grid and "\\examgridtrue" or "\\examgridfalse"

  -- Build LaTeX command definitions for metadata
  -- Note: We define all commands here because header-includes run before include-in-header
  local latex_cmds = string.format([[
\newif\ifsolution
%s
\newif\ifexamgrid
%s
\newcommand{\examsemester}{%s}
\newcommand{\examcourse}{%s}
\newcommand{\examcourseshort}{%s}
\newcommand{\examinstructor}{%s}
\newcommand{\examdate}{%s}
\newcommand{\examduration}{%s}
]], solution_flag, grid_flag, semester, course, course_short, instructor, exam_date, duration)

  -- Calculate total points
  local total_points = 0
  for _, pts in pairs(exercise_points) do
    total_points = total_points + pts
  end

  -- Add exercise count and total points
  latex_cmds = latex_cmds .. string.format([[
\newcommand{\examexercisecount}{%d}
\newcommand{\examtotalpoints}{%s}
]], exercise_count, format_points(total_points))

  -- Add points table if we found any points
  local points_table, _ = generate_points_table(exercise_points, exam_lang)
  if points_table then
    latex_cmds = latex_cmds .. "\n\\newcommand{\\exampointstable}{%\n" .. points_table .. "%\n}"
  end

  -- Add header/footer configuration (language-aware)
  -- Wrap in AtBeginDocument so it runs after fancyhdr is loaded
  local header_left = string.format(strings.header_left, "\\examsemester{}", "\\examcourseshort")
  local footer_page = string.format(strings.footer_page, "\\thepage{}", "\\pageref{LastPage}")
  latex_cmds = latex_cmds .. string.format([[

%% Header/footer (language: %s)
\AtBeginDocument{
  \fancyhead[L]{\small %s}
  \fancyhead[R]{}
  \fancyfoot[R]{%s}
}
]], exam_lang, header_left, footer_page)

  -- Add extra pages at end of document (with grid if enabled)
  if extra_pages > 0 then
    local extra_pages_latex = generate_extra_pages(extra_pages, exam_lang, use_grid)
    latex_cmds = latex_cmds .. "\n\\AtEndDocument{" .. extra_pages_latex .. "}"
  end

  -- Add to header-includes
  local header_includes = doc.meta["header-includes"]
  if header_includes == nil then
    header_includes = pandoc.MetaList({})
  elseif header_includes.t ~= "MetaList" then
    header_includes = pandoc.MetaList({header_includes})
  end

  table.insert(header_includes, pandoc.MetaBlocks({pandoc.RawBlock("latex", latex_cmds)}))
  doc.meta["header-includes"] = header_includes

  -- Insert coverpage at beginning of document
  -- Note: We read and insert the file directly because setting include-before-body
  -- dynamically doesn't work - Quarto resolves file includes before Lua filters run
  local coverpage_latex = read_coverpage(exam_lang)
  if coverpage_latex and coverpage_latex ~= "" then
    table.insert(doc.blocks, 1, pandoc.RawBlock("latex", coverpage_latex))
  end

  return doc
end

return {{Pandoc = Pandoc}}
