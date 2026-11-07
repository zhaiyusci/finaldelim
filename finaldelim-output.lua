-- Copyright (C) 2026 Yu Zhai. LPPL 1.3c or later.
-- PDF output or driver-specific DVI specials; math layout is backend-independent.
local M={}
local whatsit=node.id('whatsit')
local special=node.subtype('special')
local colorstack=node.subtype('pdf_colorstack')
local literal=node.subtype('pdf_literal')
function M.is_dvi() return tex.outputmode==0 end
function M.driver()
 local driver=token.get_macro('fdDVIDriver') or 'auto'
 if driver=='auto' then driver=(token.get_macro('Gin@driver') or ''):gsub('%.def$','') end
 assert(driver=='dvipdfmx' or driver=='dvips' or driver=='dvisvgm',
  'finaldelim: select dvi-driver=dvipdfmx, dvips or dvisvgm to match the converter')
 return driver
end
-- Translate only the self-contained graphics language emitted by our renderer
-- and lua-visual-debug. Fill and stroke colors stay separate, as in PDF.
function M.postscript(data,color,svg)
 local model,args=(color or 'gray 0'):match('^%s*(%a+)%s+(.+)$')
 local colorop=({gray='setgray',rgb='setrgbcolor',cmyk='setcmykcolor',hsb='sethsbcolor'})[model]
 local initial
 if colorop then initial=args..' '..colorop
 else
  local name=(color or 'Black'):match('^%s*(%a+)%s*$')
  assert(name,'finaldelim: unsupported PostScript color')
  initial=({Black='0 setgray',White='1 setgray'})[name] or ('TeXDict begin '..name..' end')
 end
 local out={'" newpath '..initial..' 16 dict begin /FDfill {'..initial..'} def /FDstroke /FDfill load def'}
 local stack={}
 local function take(n)
  assert(#stack>=n,'finaldelim: incomplete drawing operands')
  local args={};local start=#stack-n+1
  for i=1,n do args[i]=table.remove(stack,start) end
  return table.concat(args,' ')
 end
 local simple={m={2,'moveto'},l={2,'lineto'},c={6,'curveto'},h={0,'closepath'},
  w={1,'setlinewidth'},J={1,'setlinecap'},j={1,'setlinejoin'},M={1,'setmiterlimit'}}
 for op in data:gsub('%[',' [ '):gsub('%]',' ] '):gmatch('%S+') do
  if tonumber(op) or op=='[' or op==']' then stack[#stack+1]=op
  elseif simple[op] then
   local spec=simple[op];local args=take(spec[1])
   -- SVG has no device-dependent zero-width hairline. Give diagnostic
   -- hairlines a thin, explicit width instead of dvisvgm's 0.5bp fallback.
   if svg and op=='w' and tonumber(args)==0 then args='0.1' end
   out[#out+1]=args..' '..spec[2]
  elseif op=='q' then out[#out+1]='gsave 8 dict begin'
  elseif op=='Q' then out[#out+1]='end grestore'
  elseif op=='re' then
   out[#out+1]=take(4)..' 4 dict begin /H exch def /W exch def /Y exch def /X exch def X Y moveto W 0 rlineto 0 H rlineto W neg 0 rlineto closepath end'
  elseif op=='d' then out[#out+1]=take(#stack)..' setdash'
  elseif op=='rg' or op=='RG' or op=='g' or op=='G' or op=='k' or op=='K' then
   local n=(op:lower()=='rg' and 3) or (op:lower()=='k' and 4) or 1
   local command=({[1]='setgray',[3]='setrgbcolor',[4]='setcmykcolor'})[n]
   out[#out+1]='/'..(op==op:lower() and 'FDfill' or 'FDstroke')..' {'..take(n)..' '..command..'} def'
  elseif op=='f' or op=='f*' then
   out[#out+1]='gsave FDfill '..(op=='f*' and 'eofill' or 'fill')..' grestore newpath'
  elseif op=='S' or op=='s' then
   out[#out+1]=(op=='s' and 'closepath ' or '')..'FDstroke stroke'
  elseif op=='B' or op=='b' then
   out[#out+1]=(op=='b' and 'closepath ' or '')..'gsave FDfill fill grestore FDstroke stroke'
  elseif op=='n' then out[#out+1]='newpath'
  else error('finaldelim: unsupported drawing operator for PostScript: '..op) end
 end
 assert(#stack==0,'finaldelim: unused drawing operands')
 out[#out+1]='end';return table.concat(out,'\n')
end
local function new_special(data)
 local n=node.new('whatsit','special');n.data=data;return n
end
function M.literal(data)
 if M.is_dvi() and M.driver()=='dvipdfmx' then return new_special('pdf:content '..data) end
 -- PostScript needs the actual shipout color, especially in dvisvgm.
 -- Keep an internal literal until the page walker sees surrounding colors.
 local n=node.new('whatsit','pdf_literal');n.mode=0;n.data=data;return n
end
function M.color(command,data)
 if M.is_dvi() then
  if command==1 then return new_special('color push '..data) end
  assert(command==2,'finaldelim: unsupported DVI color operation')
  return new_special('color pop')
 end
 local n=node.new('whatsit','pdf_colorstack')
 n.stack,n.command,n.data=0,command,data or '';return n
end
function M.color_action(n)
 if n.id~=whatsit then return end
 if not M.is_dvi() and n.subtype==colorstack then
  assert(n.stack==0,'finaldelim: non-default PDF color stacks are unsupported')
  return n.command,n.data
 elseif M.is_dvi() and n.subtype==special then
  local data=n.data:match('^color%s+push%s+(.+)$')
  if data then return 1,data end
  if n.data:match('^color%s+pop%s*$') then return 2 end
 end
end
-- lua-visual-debug emits origin-relative PDF literals, including when its
-- package installs a page-wide callback. Adapt those after it has run.
local page_colors={}
local function convert(box,leader)
 local n=box.list
 while n do
  local nextnode=n.next
  local command,data=M.color_action(n)
  if command==1 then page_colors[#page_colors+1]=data
  elseif command==2 then
   assert(#page_colors>0,'finaldelim: unbalanced DVI shipout color stack')
   page_colors[#page_colors]=nil
  end
  if n.id==node.id('hlist') or n.id==node.id('vlist') then convert(n,leader)
  elseif n.id==node.id('glue') and n.leader then convert(n.leader,true)
  elseif leader and n.id==node.id('glyph') then
   -- luaotfload's DVI walker does not visit leader templates. Native amsmath
   -- long arrows contain such templates, even when drawing is disabled.
   local f=font.getfont(n.font)
   local mapping=f and f.backend_font
   if mapping and mapping[n.char] then n.char,n.font=mapping[n.char],mapping.font end
  elseif n.id==whatsit and n.subtype==literal then
   assert(n.mode==0,'finaldelim: DVI conversion requires origin-relative literals')
   local ps=M.driver()~='dvipdfmx'
   local color=page_colors[#page_colors] or 'gray 0'
   local out=new_special(not ps and ('pdf:content '..n.data) or M.postscript(n.data,color,M.driver()=='dvisvgm'))
   out.attr=n.attr
   -- dvisvgm mirrors PostScript paint colors into its SVG state. Restore the
   -- DVI color explicitly so a debug stroke cannot recolor following glyphs.
   if ps then box.list=node.insert_before(box.list,n,M.color(1,color)) end
   box.list=node.insert_before(box.list,n,out)
   if ps then box.list=node.insert_before(box.list,n,M.color(2)) end
   box.list=node.remove(box.list,n);node.flush_node(n)
  end
  n=nextnode
 end
end
local function directions(box,inherited)
 local direction=box.dir or inherited or 'TLT'
 if box.direction==nil then box.dir=direction end
 for n in node.traverse(box.list) do
  if n.id==node.id('hlist') or n.id==node.id('vlist') then directions(n,direction) end
 end
end
luatexbase.add_to_callback('pre_shipout_filter',function(box)
 if luatexbase.in_callback('pre_shipout_filter','lvd') then directions(box) end
 return true
end,'finaldelim.debug-directions')
luatexbase.declare_callback_rule('pre_shipout_filter','finaldelim.debug-directions','before','lvd')
luatexbase.add_to_callback('pre_shipout_filter',function(box)
 if M.is_dvi() then convert(box) end
 return true
end,'finaldelim.dvi')
luatexbase.declare_callback_rule('pre_shipout_filter','finaldelim.dvi','after','lvd')
return M
