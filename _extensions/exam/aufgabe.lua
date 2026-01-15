-- aufgabe.lua - Lua filter for LMU Exam template
-- Handles exercise header formatting, metadata injection, and points tracking

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
    table.insert(rows, string.format("  Aufgabe %d & %d & \\\\", num, pts))
  end

  if #rows == 0 then
    return nil  -- No points found, use default table
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
  \textbf{Summe} & \textbf{]] .. total .. [[} & \\
  \hline
\end{tabular}]]

  return table_latex
end

-- Extract points from a RawInline or RawBlock
local function extract_points(el)
  if el.t == "RawInline" or el.t == "RawBlock" then
    if el.format == "tex" or el.format == "latex" then
      local points = el.text:match("\\punkte%s*{%s*(%d+)%s*}")
      if points then
        return tonumber(points)
      end
    end
  end
  return nil
end

-- Main filter function - processes entire document
function Pandoc(doc)
  local exercise_count = 0
  local current_exercise = 0
  local exercise_points = {}

  -- Walk through blocks in document order
  local new_blocks = {}
  for _, block in ipairs(doc.blocks) do
    -- Check if this is an Aufgabe header
    if block.t == "Header" and block.level == 2 then
      local text = pandoc.utils.stringify(block.content)
      if text:match("^Aufgabe") then
        exercise_count = exercise_count + 1
        current_exercise = exercise_count

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
      end
    end

    -- Check for points in RawBlock
    if block.t == "RawBlock" then
      local pts = extract_points(block)
      if pts and current_exercise > 0 then
        exercise_points[current_exercise] = (exercise_points[current_exercise] or 0) + pts
      end
    end

    -- Walk through inline content to find RawInline points
    if block.content then
      pandoc.walk_block(block, {
        RawInline = function(el)
          local pts = extract_points(el)
          if pts and current_exercise > 0 then
            exercise_points[current_exercise] = (exercise_points[current_exercise] or 0) + pts
          end
          return el
        end
      })
    end

    table.insert(new_blocks, block)
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
  local latex_cmds = string.format([[
%s
\renewcommand{\examsemester}{%s}
\renewcommand{\examveranstaltung}{%s}
\renewcommand{\examveranstaltungkurz}{%s}
\renewcommand{\examdozent}{%s}
\renewcommand{\examdatum}{%s}
\renewcommand{\examdauer}{%s}
]], solution_flag, semester, veranstaltung, veranstaltung_kurz, dozent, datum, dauer)

  -- Calculate total points
  local total_points = 0
  for _, pts in pairs(exercise_points) do
    total_points = total_points + pts
  end

  -- Add exercise count and total points
  latex_cmds = latex_cmds .. string.format([[
\renewcommand{\anzahlaufgaben}{%d}
\renewcommand{\gesamtpunkte}{%d}
]], exercise_count, total_points)

  -- Add points table if we found any points
  local points_table = generate_points_table(exercise_points)
  if points_table then
    latex_cmds = latex_cmds .. "\n\\renewcommand{\\punktetabelle}{%\n" .. points_table .. "%\n}"
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
