-- solution.lua - Lua filter for solution toggle and auto-points tracking
-- Handles solution blocks with scalable answer boxes and point markers

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
      points = points + count_points_in_text(el.text)
    elseif el.content then
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
    elseif block.t == "Header" then
      points = points + count_points_in_inlines(block.content)
    end
  end
  return points
end

-- Estimate height (in cm) needed for content
local function estimate_content_height(blocks)
  local total_chars = 0
  local extra_lines = 0

  for _, block in ipairs(blocks) do
    if block.t == "Para" or block.t == "Plain" then
      local text = pandoc.utils.stringify(block.content)
      total_chars = total_chars + #text
      extra_lines = extra_lines + 1
    elseif block.t == "Math" or (block.t == "Para" and block.content[1] and block.content[1].t == "Math") then
      extra_lines = extra_lines + 2
    elseif block.t == "BulletList" or block.t == "OrderedList" then
      for _, item in ipairs(block.content) do
        local text = pandoc.utils.stringify(item)
        total_chars = total_chars + #text
        extra_lines = extra_lines + 0.5
      end
    elseif block.t == "RawBlock" then
      extra_lines = extra_lines + 2
    elseif block.t == "Div" then
      local nested = estimate_content_height(block.content)
      extra_lines = extra_lines + nested / 0.5
    else
      local text = pandoc.utils.stringify(block)
      total_chars = total_chars + #text
    end
  end

  local text_lines = total_chars / 80
  local total_lines = text_lines + extra_lines
  local height = math.max(2, total_lines * 0.5)
  height = math.floor(height * 2 + 0.5) / 2

  return height
end

-- Format points for display (handles decimals nicely)
local function format_points(pts)
  if pts == math.floor(pts) then
    return tostring(math.floor(pts))
  else
    return string.format("%.1f", pts)
  end
end

-- Main filter function
function Pandoc(doc)
  -- Check solution mode
  local is_solution_mode = meta_to_bool(doc.meta["solution"], false)

  -- Check answerfields setting (default: true)
  local show_answerfields = meta_to_bool(doc.meta["answerfields"], true)

  -- Check grid setting (default: true)
  local use_grid = meta_to_bool(doc.meta["grid-paper"], true)

  -- Build LaTeX command definitions
  local solution_flag = is_solution_mode and "\\solutiontrue" or "\\solutionfalse"
  local grid_flag = use_grid and "\\examgridtrue" or "\\examgridfalse"

  local latex_cmds = string.format([[
\newif\ifsolution
%s
\newif\ifexamgrid
%s
]], solution_flag, grid_flag)

  -- Add to header-includes
  local header_includes = doc.meta["header-includes"]
  if header_includes == nil then
    header_includes = pandoc.MetaList({})
  elseif header_includes.t ~= "MetaList" then
    header_includes = pandoc.MetaList({header_includes})
  end

  table.insert(header_includes, pandoc.MetaBlocks({pandoc.RawBlock("latex", latex_cmds)}))
  doc.meta["header-includes"] = header_includes

  -- Process blocks
  local new_blocks = {}

  for _, block in ipairs(doc.blocks) do
    -- Transform .solution divs
    if block.t == "Div" and block.classes:includes("solution") then
      local box_attr = block.attributes["box"]

      if is_solution_mode then
        -- Solution mode: show solution with tcolorbox styling
        block.attributes["box"] = nil

        local new_content = {
          pandoc.RawBlock("latex", "\\begin{solutionbox}")
        }
        for _, el in ipairs(block.content) do
          table.insert(new_content, el)
        end
        table.insert(new_content, pandoc.RawBlock("latex", "\\end{solutionbox}"))
        block.content = new_content

        block.classes = pandoc.List({"content-hidden"})
        block.attributes["unless-meta"] = "solution"
      else
        -- Exam mode: replace solution with answer field (if enabled)
        if show_answerfields then
          local height
          if box_attr then
            height = box_attr
          else
            height = estimate_content_height(block.content)
          end

          block.content = {
            pandoc.RawBlock("latex", string.format("\\examanswerfield{%s}", height))
          }
          block.classes = pandoc.List({})
          block.attributes = {}
        else
          goto continue
        end
      end
    end

    table.insert(new_blocks, block)
    ::continue::
  end

  doc.blocks = new_blocks
  return doc
end

return {{Pandoc = Pandoc}}
