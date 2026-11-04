-- Copyright (C) 2026 Yu Zhai. LPPL 1.3c or later.
-- Experimental reference implementation; not loaded by finaldelim.sty.
local M = {}
local layouts = {}
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

function M.render(source, target, reference, rejoined)
  local original = tex.box[source]
  local before = snapshot(original)
  if reference then
    assert(before == snapshot(tex.box[reference]), 'Cut markers changed native math geometry')
  end
  local parts = partition(original)
  local joined = {}
  for _, part in ipairs(parts) do append(joined, node.copy(part.box)) end
  local joined_box = pack(joined.head)
  if snapshot(joined_box) ~= before then
    local f = assert(io.open('build/flat-before.txt', 'w')); f:write(before); f:close()
    f = assert(io.open('build/flat-after.txt', 'w')); f:write(snapshot(joined_box)); f:close()
    error('Partition changed physical glyph/rule positions')
  end
  assert(joined_box.width == original.width, 'Partition changed total width')
  if rejoined then tex.box[rejoined] = joined_box else node.flush_node(joined_box) end

  local rows, row, widths = {}, {}, {}
  for _, part in ipairs(parts) do
    row[#row + 1] = part.box
    local col = #row
    widths[col] = math.max(widths[col] or 0, part.box.width)
    if part.cut == 2 then rows[#rows + 1], row = row, {} end
  end
  rows[#rows + 1] = row
  local vertical, previous = {}, nil
  for _, cells in ipairs(rows) do
    local horizontal = {}
    for col = 1, #widths do
      local b = cells[col] or pack(nil)
      local pad = node.new('kern'); pad.kern = widths[col] - b.width
      if col % 2 == 1 then append(horizontal, pad); append(horizontal, b)
      else append(horizontal, b); append(horizontal, pad) end
      if col % 2 == 0 and col < #widths then
        local gap = node.new('kern'); gap.kern = tex.sp('2em'); append(horizontal, gap)
      end
    end
    local line = pack(horizontal.head)
    if previous then
      local gap = node.new('kern')
      gap.kern = math.max(tex.sp('3pt'), tex.sp('15pt') - previous.depth - line.height)
      append(vertical, gap)
    end
    append(vertical, line)
    previous = line
  end
  tex.box[target] = node.vpack(vertical.head)
  layouts[target] = widths
  texio.write_nl('term and log', 'FLAT CORE PASS: ' .. #rows .. ' rows, ' .. #parts .. ' cells; exact leaf positions')
end

-- Diagnostic overlay only: mark real row hboxes without changing dimensions.
function M.outline_rows(register)
  local sp_to_bp = 72 / 72.27 / 65536
  local index = 0
  for line in node.traverse(tex.box[register].list) do
    if line.id == hlist then
      index = index + 1
      local mark = node.new('whatsit', 'pdf_literal')
      mark.mode = 0
      mark.data = string.format('q 0 0 1 RG 0.3 w 0 %.8f %.8f %.8f re S Q',
        -line.depth * sp_to_bp, line.width * sp_to_bp,
        (line.height + line.depth) * sp_to_bp)
      line.list = node.insert_before(line.list, line.list, mark)
      texio.write_nl('log', string.format('FLAT ROW BOX %d: width=%dsp height=%dsp depth=%dsp',
        index, line.width, line.height, line.depth))
    end
  end
end

-- The guide uses the actual column widths used by the row builder.
function M.show_alignment(register)
  local scale = 72 / 72.27 / 65536
  local grid = tex.box[register]
  local widths = assert(layouts[register], 'Missing grid layout')
  local axes, x = {}, 0
  for col = 1, #widths - 1 do
    x = x + widths[col]
    if col % 2 == 0 then x = x + tex.sp('2em') end
    axes[#axes + 1] = x * scale
  end
  local first = true
  for line in node.traverse(grid.list) do
    if line.id == hlist then
      local commands = {'q 0.8 0 0 RG 0.45 w'}
      for _, axis in ipairs(axes) do
        if first then
          commands[#commands + 1] = string.format(
            '[2 2] 0 d %.8f %.8f m %.8f %.8f l S [] 0 d',
            axis, line.height * scale, axis, (line.height-grid.height-grid.depth)*scale)
        end
        commands[#commands + 1] = string.format(
          '%.8f 0 m %.8f 0 l S %.8f -1.5 m %.8f 1.5 l S',
          axis-1.5, axis+1.5, axis, axis)
      end
      commands[#commands + 1] = 'Q'
      local mark = node.new('whatsit', 'pdf_literal')
      mark.mode, mark.data = 0, table.concat(commands, ' ')
      line.list = node.insert_before(line.list, line.list, mark)
      first = false
    end
  end
end

return M
