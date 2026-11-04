local M={}
local detail=assert(io.open('build/delimiter-outlines.jsonl','w'))
local out=assert(io.open('build/delimiter-atlas.csv','w'))
out:write('font,delimiter,target_pt,width_pt,total_pt,glyph_count,glyph_ids\n')
function M.record(fontname,delim,target)
 local function find_fence(head)
  local previous
  for n in node.traverse(head) do
   if n.id==node.id('rule') and previous and
      (previous.id==node.id('hlist') or previous.id==node.id('vlist')) then return previous end
   previous=n
  end
  for n in node.traverse(head) do
   if n.id==node.id('hlist') or n.id==node.id('vlist') then
    local found=find_fence(n.list);if found then return found end
   end
  end
 end
 local b=assert(find_fence(tex.box[0].list),'Missing delimiter box');local ids={}
 local function scan(head)
  for n in node.traverse(head) do
   if n.id==node.id('glyph') then ids[#ids+1]=string.format('%X',n.char)
   elseif n.id==node.id('hlist') or n.id==node.id('vlist') then scan(n.list) end
  end
 end
 scan(b.list)
 local placed={}
 local function walk(box,x,y)
  local vertical=box.id==node.id('vlist')
  local cursor=vertical and y+box.height or x
  for n in node.traverse(box.list) do
   local id=n.id
   if id==node.id('glyph') then
    local f=font.getfont(n.font)
    placed[#placed+1]=string.format('{"index":%d,"x":%.12g,"y":%.12g,"size":%.12g}',
     assert(f.characters[n.char].index), (cursor+(n.xoffset or 0))/65536,
     (y+(n.yoffset or 0))/65536, f.size/65536)
    cursor=cursor+n.width
   elseif id==node.id('hlist') or id==node.id('vlist') then
    if vertical then
     walk(n,x+n.shift,cursor-n.height);cursor=cursor-n.height-n.depth
    else walk(n,cursor,y-n.shift);cursor=cursor+n.width end
   elseif id==node.id('kern') then cursor=cursor+(vertical and -1 or 1)*n.kern
   elseif id==node.id('glue') then cursor=cursor+(vertical and -1 or 1)*node.effective_glue(n,box)
   elseif id==node.id('rule') then error('Unexpected rule inside delimiter') end
  end
 end
 walk(b,0,0)
 detail:write(string.format('{"font":"%s","delimiter":"%s","target":%d,"height":%.12g,"glyphs":[%s]}\n',
  fontname,delim,target,(b.height+b.depth)/65536,table.concat(placed,',')))
 detail:flush()
 out:write(string.format('%s,%s,%s,%.6f,%.6f,%d,%s\n',fontname,delim,target,b.width/65536,(b.height+b.depth)/65536,#ids,table.concat(ids,'+')))
 out:flush()
 tex.sprint(string.format('%.2f / %d',(b.height+b.depth)/65536,#ids))
end
return M
