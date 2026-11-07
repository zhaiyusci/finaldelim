-- Copyright (C) 2026 Yu Zhai. LPPL 1.3c or later.
-- LuaTeX backend: native math layout followed by physical cell partition.
local M = {}
local output = require('finaldelim-output')
local hlist, vlist = node.id('hlist'), node.id('vlist')
local whatsit, glue, kern = node.id('whatsit'), node.id('glue'), node.id('kern')
local marker_id = 0x4D53
local function pack(head)
  if head then return node.hpack(head) end
  return node.new('hlist')
end

function M.marker(kind)
  local n = node.new('whatsit', 'user_defined')
  n.user_id, n.type, n.value = marker_id, 100, kind
  node.write(n)
end

local function is_marker(n)
  return n.id == whatsit and n.subtype == node.subtype('user_defined')
    and n.user_id == marker_id
end

local function contains_cut(head)
  for n in node.traverse(head) do
    if is_marker(n) then return true end
    if (n.id == hlist or n.id == vlist) and contains_cut(n.list) then return true end
  end
  return false
end

local function append(list, n)
  n.prev, n.next = list.tail, nil
  if list.tail then list.tail.next = n else list.head = n end
  list.tail = n
end

-- Only ancestors of explicit cuts are opened. Every other box, including
-- script/fraction/radical boxes and their shifts, is moved as an opaque node.
local function partition(parent)
  local parts, current = {}, {}
  local function finish(kind)
    local b = pack(current.head)
    b.shift, b.dir = parent.shift, parent.dir
    parts[#parts + 1] = {box = b, cut = kind}
    current = {}
  end
  local head = parent.list
  parent.list = nil
  local old_width, natural_width = parent.width, 0
  local n = head
  while n do
    local next_node = n.next
    -- Freeze only glue in the opened wrapper; opaque boxes retain their own
    -- glue settings. Do this before detaching the node from its parent.
    if n.id == glue then
      local width = node.effective_glue(n, parent)
      n.width, n.stretch, n.shrink = width, 0, 0
    end
    n.next, n.prev = nil, nil
    if is_marker(n) then
      local kind = n.value
      node.free(n)
      finish(kind)
    elseif (n.id == hlist or n.id == vlist) and contains_cut(n.list) then
      assert(n.id == hlist, 'Explicit cuts inside vertical math structures are unsupported')
      assert(n.dir == 'TLT', 'Only left-to-right formula boxes are supported')
      local children = partition(n)
      node.free(n)
      for _, child in ipairs(children) do
        append(current, child.box)
        if child.cut then finish(child.cut) end
      end
    else
      append(current, n)
    end
    n = next_node
  end
  finish(nil)
  for _, part in ipairs(parts) do natural_width = natural_width + part.box.width end
  -- Preserve a wrapper's explicit width, including trailing italic correction.
  local delta = old_width - natural_width
  if delta ~= 0 then
    local b = parts[#parts].box
    local k = node.new('kern'); k.kern = delta
    if b.list then b.list = node.insert_after(b.list, node.tail(b.list), k)
    else b.list = k end
    b.width = b.width + delta
  end
  return parts
end

local function width(n, parent)
  if n.id == glue then return node.effective_glue(n, parent) end
  if n.id == kern then return n.kern end
  if n.id == node.id('math') then return n.surround end
  return n.width or 0
end

-- A test oracle: physical leaf positions, not the implementation's wrapper
-- structure. Includes rules (fraction bars, radical bars, etc.) and glyphs.
local function snapshot(box)
  local result = {}
  local function record(values)
    for i = 2, #values do values[i] = string.format('%.0f', values[i]) end
    result[#result + 1] = table.concat(values, ':')
  end
  local function visit(b, x, y)
    if b.id == hlist then
      for n in node.traverse(b.list) do
        if n.id == hlist or n.id == vlist then
          visit(n, x, y + n.shift)
        elseif n.id == node.id('glyph') then
          record({'g', n.font, n.char,
            x + n.xoffset, y - n.yoffset, n.width, n.height, n.depth})
        elseif n.id == node.id('rule') then
          record({'r', x, y, n.width, n.height, n.depth})
        end
        x = x + width(n, b)
      end
    else
      y = y - b.height
      for n in node.traverse(b.list) do
        if n.id == hlist or n.id == vlist then
          y = y + n.height
          visit(n, x + n.shift, y)
          y = y + n.depth
        elseif n.id == kern then y = y + n.kern
        elseif n.id == glue then y = y + node.effective_glue(n, b)
        elseif n.id == node.id('rule') then
          y = y + n.height
          record({'r', x, y, n.width, n.height, n.depth})
          y = y + n.depth
        end
      end
    end
  end
  visit(box, 0, 0)
  return table.concat(result, '\n')
end

local grids, serial = {}, 0
local color_node = output.color
local function track_colors(head, stack)
  for n in node.traverse(head) do
    local command,data = output.color_action(n)
    if command then
      if command == 1 then stack[#stack+1] = data
      elseif command == 2 then
        assert(#stack > 0, 'finaldelim: unbalanced source color stack')
        stack[#stack] = nil
      elseif command == 0 then
        assert(#stack > 0, 'finaldelim: unscoped PDF color assignment')
        stack[#stack] = data
      end
    elseif n.id == hlist or n.id == vlist then track_colors(n.list, stack) end
  end
end

-- Every cell is a separate math scope in amsmath. Reopen/close the original
-- color state at the cut, without inserting math atoms or changing geometry.
local function isolate_color(box, stack, base)
  local list = {}
  append(list, color_node(1, base))
  for _, color in ipairs(stack) do append(list, color_node(1, color)) end
  track_colors(box.list, stack)
  local n = box.list
  while n do local next_node = n.next; append(list, n); n = next_node end
  for _ = 1, #stack do append(list, color_node(2)) end
  append(list, color_node(2))
  box.list = list.head
end

function M.prepare(source, expected, base)
  local original = tex.box[source]
  local before = snapshot(original)
  local parts = partition(original)
  assert(#parts == expected, 'finaldelim: source cuts and output cells disagree')
  local joined = {}
  for _, part in ipairs(parts) do append(joined, node.copy(part.box)) end
  local check = pack(joined.head)
  assert(snapshot(check) == before and check.width == original.width,
    'finaldelim: partition changed native math geometry')
  node.flush_node(check)
  local stack = {}
  for _, part in ipairs(parts) do isolate_color(part.box, stack, base) end
  assert(#stack == 0, 'finaldelim: source color stack did not close')
  serial = serial + 1
  grids[serial] = parts
  tex.sprint('\\def\\msluagrid{' .. serial .. '}')
end

-- Newly constructed math boxes can inherit their direction at output time.
-- lua-visual-debug needs it explicitly before shipout. Normalize only the
-- copied diagnostic tree, preserving the formula's stored cells.
local function debug_directions(box, inherited)
  local direction = box.dir or inherited or 'TLT'
  if box.direction == nil then box.dir = direction end
  for n in node.traverse(box.list) do
    if n.id == hlist or n.id == vlist then debug_directions(n, direction) end
  end
end

function M.cell(id, index, measuring, boxes, alignment, odd)
  local part = assert(grids[id] and grids[id][index], 'finaldelim: missing cell')
  local b = node.copy(part.box)
  if not measuring and boxes then
    local before = snapshot(b)
    local visual = require('lua-visual-debug')
    local wrapper = pack(b)
    debug_directions(wrapper)
    visual.show_page_elements(wrapper)
    b = wrapper.list; wrapper.list = nil; node.free(wrapper)
    assert(snapshot(b) == before, 'finaldelim: diagnostics changed math geometry')
  end
  if not measuring and alignment then
    local visual = require('lua-visual-debug')
    local config = visual.params.rule
    local scale = 72 / 72.27 / 65536
    local x = odd and b.width * scale or 0
    local mark = output.literal(string.format('q %s %g w [2 2] 0 d %g %g m %g %g l S [] 0 d %g 0 m %g 0 l S Q',
      config.color, config.width, x, -b.depth*scale, x, b.height*scale, x-1.5, x+1.5))
    if b.list then b.list = node.insert_before(b.list, b.list, mark) else b.list = mark end
  end
  node.write(b)
end

function M.release(id)
  for _, part in ipairs(assert(grids[id])) do node.flush_node(part.box) end
  grids[id] = nil
end

return M
