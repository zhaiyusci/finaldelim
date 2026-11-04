-- Experimental measure -> single-line layout -> physical partition pipeline.
-- The input is an already parsed math list; user source is never replayed.
local M = { enabled = false, measured = 0 }
local fence, noad, sub = node.id('fence'), node.id('noad'), node.id('sub_mlist')
local hl, vl = node.id('hlist'), node.id('vlist')
local function marker(n)
 return n.id == node.id('whatsit') and n.subtype == node.subtype('user_defined') and n.user_id == 0x4D53
end
local function hascut(head)
 for n in node.traverse(head) do
  if marker(n) then return true end
  if (n.id == hl or n.id == vl) and hascut(n.list) then return true end
 end
 return false
end
local function dimensions(box)
 local cells, index, rows = {{h=0,d=0}}, 1, 0
 local function scan(list, shift)
  for n in node.traverse(list) do
   if marker(n) then
    if n.value == 2 then rows = rows + 1 end
    index = index + 1; cells[index] = {h=0,d=0}
   elseif (n.id == hl or n.id == vl) and hascut(n.list) then
    assert(n.id == hl, 'Endpoint prototype requires horizontal cuts')
    scan(n.list, shift + n.shift)
   elseif n.id == hl or n.id == vl or n.id == node.id('glyph') or n.id == node.id('rule') then
    local s = shift + ((n.id == hl or n.id == vl) and n.shift or 0)
    cells[index].h = math.max(cells[index].h, n.height - s)
    cells[index].d = math.max(cells[index].d, n.depth + s)
   end
  end
 end
 scan(box.list, 0)
 return cells[1], cells[index], rows
end
local function measure(head, stop, style)
 local copy = node.copy_list(head, stop)
 local box = node.hpack(node.mlist_to_hlist(copy, style, false))
 local a,b,rows = dimensions(box)
 node.flush_node(box)
 return a,b,rows
end
local function delimiters(first,last,h,d,style)
 -- Let native left/right select AND position both delimiters around the axis.
 local l,r = node.copy(first),node.copy(last)
 l.next,l.prev,r.next,r.prev = nil,nil,nil,nil
 l.height,l.depth,r.height,r.depth = 0,0,0,0
 local rule = node.new('rule'); rule.width,rule.height,rule.depth = 0,h,d
 l.next,rule.prev,rule.next,r.prev = rule,l,r,rule
 local result = node.mlist_to_hlist(l,style,false)
 local tail = node.tail(result)
 assert(result.id == hl and tail.id == hl, 'Expected native delimiter boxes')
 local middle = result.next
 result.next,middle.prev,tail.prev.next,tail.prev = nil,nil,nil,nil
 node.flush_list(middle)
 return result,tail
end
local function boxed_noad(box, subtype, attr)
 local n = node.new('noad',subtype)
 n.attr = attr
 n.nucleus = node.new('sub_box'); n.nucleus.head = box
 return n
end
local process
local function children(head,style)
 for n in node.traverse(head) do
  if n.id == node.id("style") then style = n.style end
  if n.id == noad and n.nucleus and n.nucleus.id == sub then
   local b = process(n.nucleus.head,style)
   if b then
    n.nucleus.head = nil; node.free(n.nucleus)
    n.nucleus = node.new('sub_box'); n.nucleus.head = b
   end
  end
 end
end
process = function(head,style)
 children(head,style)
 node.slide(head)
 local first,last = head,node.tail(head)
 if not first then return end
 local paired = first.id == fence and last.id == fence and first ~= last
 local a,b,rows = measure(paired and first.next or head, paired and last or nil,style)
 if rows == 0 then return end
 if paired then
  local h,d = math.max(a.h,b.h),math.max(a.d,b.d)
  local lbox,rbox = delimiters(first,last,h,d,style)
  local l,r = boxed_noad(lbox,6,first.attr),boxed_noad(rbox,7,last.attr)
  local inner,ending = first.next,last.prev
  l.next,inner.prev,ending.next,r.prev = inner,l,r,ending
  first.next,first.prev,last.next,last.prev = nil,nil,nil,nil
  node.flush_node(first); node.flush_node(last)
  head = l
  M.measured = M.measured + 1
  texio.write_nl('term and log',string.format('ENDPOINT pair %d: %.3fpt / %.3fpt',M.measured,h/65536,d/65536))
 end
 -- Final continuous layout. Preserve every actual child box and its dimensions.
 local box = node.hpack(node.mlist_to_hlist(head,style,false))
 local _,ending = dimensions(box)
 -- Only the enclosing math atom's attachment metrics use its endpoint cell.
 -- The physical partitioner later repacks actual children into real row boxes.
 box.height,box.depth = ending.h,ending.d
 return box
end
luatexbase.add_to_callback('pre_mlist_to_hlist_filter',function(head,style)
 if M.enabled then children(head,style) end
 return head
end,'finaldelim.experimental.endpoint')
return M
