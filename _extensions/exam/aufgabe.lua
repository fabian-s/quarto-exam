-- aufgabe.lua - Lua filter for LMU Exam template
-- Handles exercise header formatting, metadata injection, and auto-points tracking

-- Point values for marker commands
local point_values = {
  ["\\p"] = 1,
  ["\\hp"] = 0.5,
  ["\\pp"] = 2,
}

-- Helper to get metadata value as string
local function meta_to_string(meta_value)
  if meta_value == nil then
    return ""
  elseif type(meta_value) == "string" then
    return meta_value
  elseif meta_value.t == "MetaInlines" then
    return pandoc.utils.stringify(meta_value)
  elseif meta_value.t == "MetaString" then
    return meta_value.text or pandoc.utils.stringify(meta_value)
  else
    return pandoc.utils.stringify(meta_value)
  end
end

-- Format points for display (handles decimals nicely)
local function format_points(pts)
  if pts == math.floor(pts) then
    return tostring(math.floor(pts))
  else
    return string.format("%.1f", pts)
  end
end

-- Generate points table LaTeX
local function generate_points_table(exercise_points)
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
    table.insert(rows, string.format("  Aufgabe %d & %s & \\\\", num, format_points(pts)))
  end

  if #rows == 0 then
    return nil, 0  -- No points found, use default table
  end

  -- Build complete table
  local table_latex = [[
\begin{tabular}{|l|c|c|}
  \hline
  & mögliche Punkte & erreichte Punkte \\
  \hline
  \hline
]] .. table.concat(rows, "\n  \\hline\n") .. [[

  \hline
  \textbf{Summe} & \textbf{]] .. format_points(total) .. [[} & \\
  \hline
\end{tabular}]]

  return table_latex, total
end

-- Check if a Div is a solution block (supports both syntaxes)
local function is_solution_div(div)
  -- New simple syntax: ::: {.solution}
  if div.classes:includes("solution") then
    return true
  end
  -- Legacy syntax: ::: {.content-hidden unless-meta="solution"}
  return div.classes:includes("content-hidden") and
         div.attributes["unless-meta"] == "solution"
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

-- Main filter function - processes entire document
function Pandoc(doc)
  local exercise_count = 0
  local current_exercise = 0
  local exercise_points = {}
  local exercise_header_indices = {}  -- Track where exercise headers are

  -- First pass: identify exercises and count points in solution blocks
  local new_blocks = {}
  for i, block in ipairs(doc.blocks) do
    -- Check if this is an Aufgabe header
    if block.t == "Header" and block.level == 2 then
      local text = pandoc.utils.stringify(block.content)
      if text:match("^Aufgabe") then
        exercise_count = exercise_count + 1
        current_exercise = exercise_count
        exercise_points[current_exercise] = 0

        -- Extract title after "Aufgabe X" if present
        local title = text:gsub("^Aufgabe%s*%d*%s*", "")

        -- Create formatted header content
        local header_text
        if title and title ~= "" then
          header_text = string.format("Aufgabe %d: %s", exercise_count, title)
        else
          header_text = string.format("Aufgabe %d", exercise_count)
        end

        block.content = {pandoc.Str(header_text)}

        -- Mark position for points injection
        table.insert(new_blocks, block)
        exercise_header_indices[#new_blocks] = current_exercise
        goto continue
      end
    end

    -- Transform .solution divs to content-hidden divs and count points
    if block.t == "Div" then
      if block.classes:includes("solution") then
        -- Transform to content-hidden syntax for Quarto processing
        block.classes = pandoc.List({"content-hidden"})
        block.attributes["unless-meta"] = "solution"
      end

      -- Count points in solution divs
      if is_solution_div(block) and current_exercise > 0 then
        local pts = count_points_in_div(block)
        exercise_points[current_exercise] = exercise_points[current_exercise] + pts
      end
    end

    table.insert(new_blocks, block)
    ::continue::
  end

  -- Second pass: add points to exercise headers (flush right on same line)
  for i, block in ipairs(new_blocks) do
    local ex_num = exercise_header_indices[i]
    if ex_num then
      local pts = exercise_points[ex_num] or 0
      if pts > 0 then
        -- Add points to header content: "Aufgabe N \hfill (X Punkte)"
        local points_str = string.format("\\hfill (%s Punkte)", format_points(pts))
        table.insert(block.content, pandoc.RawInline("latex", points_str))
      end
    end
  end

  doc.blocks = new_blocks

  -- Inject metadata and points table
  local semester = meta_to_string(doc.meta.semester)
  local veranstaltung = meta_to_string(doc.meta.veranstaltung)
  local veranstaltung_kurz = meta_to_string(doc.meta["veranstaltung-kurz"])
  -- Fall back to full name if short name not provided
  if veranstaltung_kurz == "" then
    veranstaltung_kurz = veranstaltung
  end
  local dozent = meta_to_string(doc.meta.dozent)
  local datum = meta_to_string(doc.meta.datum)
  local dauer = meta_to_string(doc.meta.dauer)

  -- Check solution mode
  local solution_mode = doc.meta.solution
  local solution_flag = "\\solutionfalse"
  if solution_mode then
    local sol_str = pandoc.utils.stringify(solution_mode)
    if sol_str == "true" then
      solution_flag = "\\solutiontrue"
    end
  end

  -- Build LaTeX command definitions for metadata
  -- Note: We define all commands here because header-includes run before include-in-header
  local latex_cmds = string.format([[
\newif\ifsolution
%s
\newcommand{\examsemester}{%s}
\newcommand{\examveranstaltung}{%s}
\newcommand{\examveranstaltungkurz}{%s}
\newcommand{\examdozent}{%s}
\newcommand{\examdatum}{%s}
\newcommand{\examdauer}{%s}
]], solution_flag, semester, veranstaltung, veranstaltung_kurz, dozent, datum, dauer)

  -- Calculate total points
  local total_points = 0
  for _, pts in pairs(exercise_points) do
    total_points = total_points + pts
  end

  -- Add exercise count and total points
  latex_cmds = latex_cmds .. string.format([[
\newcommand{\anzahlaufgaben}{%d}
\newcommand{\gesamtpunkte}{%s}
]], exercise_count, format_points(total_points))

  -- Add points table if we found any points
  local points_table, _ = generate_points_table(exercise_points)
  if points_table then
    latex_cmds = latex_cmds .. "\n\\newcommand{\\punktetabelle}{%\n" .. points_table .. "%\n}"
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

  return doc
end

return {{Pandoc = Pandoc}}
