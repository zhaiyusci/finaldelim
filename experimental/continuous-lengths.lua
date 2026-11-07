local renderer=require('finaldelim-draw')
local source=require('finaldelim-outline-fonts')
local bp=72/72.27/65536
local function first(head)
 for n in node.traverse(head) do
  if n.id==node.id('glyph') then return n end
  if n.list then local g=first(n.list);if g then return g end end
 end
end
local codes={0x28,0x29,0x5b,0x5d,0x7b,0x7d,0x7c,0x2016,0x2308,0x2309,0x230a,0x230b,0x27e8,0x27e9,0x2f,0x5c}
local function ink(box)
 local commands={}
 for line in box.list.data:gmatch('[^\n]+') do
  local op=line:match('([mlch])$')
  if op then
   local c={op}
   for number in line:gmatch('[-%d.]+') do c[#c+1]=tonumber(number) end
   commands[#commands+1]=c
  end
 end
 return source.path_bounds(commands)
end
function continuous_check()
 local fid=first(tex.box[0].list).font;local f=font.getfont(fid)
 local axis=tex.getmath('axis','text');local count=0
 for _,code in ipairs(codes) do
  local fd,spec=assert(source.get(f,code))
  local sizes={2,4,6,8,10,12,15,20,30,40,60,80,100}
  for _,id in ipairs(spec.variants) do
   local b=fd.glyphs[id].bounds;local h=(b[4]-b[2])*f.size/fd.units/65536
   for _,delta in ipairs{-.01,0,.01} do sizes[#sizes+1]=h+delta end
  end
  for _,height in ipairs(sizes) do
   local target=math.floor(height*65536+.5)
   local g=node.new('glyph');g.font=fid;g.char=code
   local old=node.hpack(g)
   local result=renderer.render(old,{delim={small_char=code}},axis+target/2,target/2-axis,'text')
   local message=string.format('%s U+%04X %.5fpt',f.fullname,code,height)
   assert(math.abs(result.height+result.depth-target)<=1,'Box height: '..message)
   assert(result.list.id==node.id('whatsit'),'Native fallback: '..message)
   local b=ink(result)
   assert(math.abs((b[4]-b[2])/bp-target)<8,'Ink height: '..message..' actual '..(b[4]-b[2])/bp/65536)
   assert(math.abs((b[4]+b[2])/2/bp-axis)<8,'Ink axis: '..message)
   node.flush_node(result);count=count+1
  end
 end
 texio.write_nl('term and log','CONTINUOUS PASS '..f.fullname..' '..count..' exact ink/box lengths')
end
