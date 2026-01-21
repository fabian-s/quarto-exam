-- aufgabe.lua - Lua filter for LMU Exam template
-- Handles exercise header formatting, metadata injection, and auto-points tracking
-- Supports auto-numbered exercises (##) and sub-exercises (###)

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

-- Convert number to letter (1=a, 2=b, etc.)
local function num_to_letter(n)
  return string.char(string.byte('a') + n - 1)
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

-- Main filter function - processes entire document
function Pandoc(doc)
  -- Check solution mode early (needed for div processing)
  local solution_mode = doc.meta.solution
  local is_solution_mode = false
  if solution_mode then
    local sol_str = pandoc.utils.stringify(solution_mode)
    is_solution_mode = (sol_str == "true")
  end

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
  local subexercise_para_indices = {}  -- block index -> {exercise, subexercise} for the paragraph after ###

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

    -- Check if this is the paragraph following a ### header
    if pending_subexercise and (block.t == "Para" or block.t == "Plain") then
      -- This paragraph becomes the sub-exercise question
      subexercise_para_indices[#new_blocks + 1] = pending_subexercise
      pending_subexercise = nil
      table.insert(new_blocks, block)
      goto continue
    end

    -- Clear pending subexercise if we hit a non-paragraph block
    if pending_subexercise and block.t ~= "Para" and block.t ~= "Plain" then
      pending_subexercise = nil
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
          -- Exam mode: replace solution with antwortfeld
          local height
          if box_attr then
            -- Use specified height
            height = box_attr
          else
            -- Estimate height from content
            height = estimate_content_height(block.content)
          end

          -- Replace div content with antwortfeld
          block.content = {
            pandoc.RawBlock("latex", string.format("\\antwortfeld{%s}", height))
          }
          -- Remove classes and attributes - this is now just an answer field
          block.classes = pandoc.List({})
          block.attributes = {}
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

      -- Create header text
      local header_text
      if title ~= "" then
        header_text = string.format("Aufgabe %d: %s", ex_num, title)
      else
        header_text = string.format("Aufgabe %d", ex_num)
      end

      -- Add points (normalsize, flush right)
      local pts = exercise_points[ex_num] or 0
      local points_str = ""
      if pts > 0 then
        points_str = string.format("{\\normalsize\\hfill [%s Punkte]}", format_points(pts))
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

    -- Format sub-exercise paragraphs (add "a)" prefix and points)
    local sub_para_info = subexercise_para_indices[i]
    if sub_para_info then
      local ex = sub_para_info[1]
      local sub = sub_para_info[2]
      local pts = subexercise_points[ex][sub] or 0
      local letter = num_to_letter(sub)

      -- Prepend letter label
      local label = pandoc.RawInline("latex", string.format("\\textbf{%s)} ", letter))

      -- Append points (flush right)
      local points_suffix = ""
      if pts > 0 then
        points_suffix = string.format(" \\hfill [%s Punkte]", format_points(pts))
      end
      local points_inline = pandoc.RawInline("latex", points_suffix)

      -- Build new content
      local new_content = {label}
      for _, el in ipairs(block.content) do
        table.insert(new_content, el)
      end
      table.insert(new_content, points_inline)

      block.content = new_content
      table.insert(final_blocks, block)
      goto continue2
    end

    -- Regular block, just add it
    table.insert(final_blocks, block)
    ::continue2::
  end

  doc.blocks = final_blocks

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
