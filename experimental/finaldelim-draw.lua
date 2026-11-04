-- Experimental outline renderer; production sizing remains unchanged when not loaded.
local M={counts={interpolated=0,assembled=0,outlined=0,profile=0,fallback=0,extrapolated=0}}
local source=dofile('experimental/finaldelim-outline-fonts.lua')
M.method=source.version
M.warnings={}
local sp_to_bp=72/72.27/65536
local hl,vl,glyph=node.id('hlist'),node.id('vlist'),node.id('glyph')
local function first_glyph(head)
 for n in node.traverse(head) do
  if n.id==glyph then return n end
  if n.id==hl or n.id==vl then local g=first_glyph(n.list);if g then return g end end
 end
end
local function emit(path,sx,sy,dx,dy,out)
 for _,c in ipairs(path) do
  local args={}
  for i=2,#c,2 do args[#args+1]=string.format('%.7f %.7f',(c[i]*sx+dx)*sp_to_bp,(c[i+1]*sy+dy)*sp_to_bp) end
  out[#out+1]=table.concat(args,' ')..' '..c[1]
 end
end
local function native_outline(box,fd)
 local out={}
 local function walk(b,x,y)
  local vertical=b.id==vl;local cursor=vertical and y+b.height or x
  for n in node.traverse(b.list) do
   if n.id==glyph then
    local f=font.getfont(n.font);local g=fd.glyphs[f.characters[n.char].index]
    if not g then error('Missing native component outline') end
    local scale=f.size/fd.units
    emit(g.path,scale,scale,cursor+(n.xoffset or 0),y+(n.yoffset or 0),out)
    cursor=cursor+n.width
   elseif n.id==hl or n.id==vl then
    if vertical then walk(n,x+n.shift,cursor-n.height);cursor=cursor-n.height-n.depth
    else walk(n,cursor,y-n.shift);cursor=cursor+n.width end
   elseif n.id==node.id('kern') then cursor=cursor+(vertical and -1 or 1)*n.kern
   elseif n.id==node.id('glue') then cursor=cursor+(vertical and -1 or 1)*node.effective_glue(n,b)
   else error('Unsupported node in native delimiter: '..node.type(n.id)) end
  end
 end
 walk(box,0,0)
 return out
end
local function replace(old,path,width,height,depth,shift)
 local n=node.new('whatsit','pdf_literal');n.mode=0
 -- A single nonzero fill paints the union of overlapping, consistently wound parts.
 n.data='q\n'..table.concat(path,'\n')..'\nf\nQ'
 local box=node.new('hlist');box.dir=old.dir;box.list=n;box.width=width;box.height=height;box.depth=depth;box.shift=shift;box.attr=old.attr
 node.flush_node(old)
 return box
end
function M.render(old,fence,h,d,style)
 if tex.count.FinalDelimDrawing~=1 then return old end
 local first=first_glyph(old.list)
 if not first then return old end -- invisible delimiter
 local f=font.getfont(first.font)
 local fd,spec=source.get(f,fence.delim.small_char)
 if not fd then
  M.counts.fallback=M.counts.fallback+1
  local reason=tostring(spec)
  if not M.warnings[reason] then M.warnings[reason]=true;texio.write_nl('term and log','finaldelim outline fallback: '..reason) end
  return old
 end
 local axis=tex.getmath('axis',style);local radius=math.max(h-axis,d+axis)
 local target=math.max(math.floor(radius/500)*tex.delimiterfactor,2*radius-tex.delimitershortfall)
 local scale=f.size/fd.units
 local height=target/scale
 local lower,upper=spec.variants[1],nil
 for _,id in ipairs(spec.variants) do
  local b=fd.glyphs[id].bounds;local H=b[4]-b[2]
  if H>=height then upper=id;break end
  lower=id
 end
 local a=fd.glyphs[lower];local b=upper and fd.glyphs[upper]
 if b then
  local ha,hb=a.bounds[4]-a.bounds[2],b.bounds[4]-b.bounds[2]
  local t=ha==hb and 0 or math.max(0,math.min(1,(height-ha)/(hb-ha)))
  local apath,bpath=a.path,b.path
  local matched=source.compatible(a,b)
  if not matched then
   apath,bpath=source.contours(a,b)
   matched=apath~=nil
  end
  if not matched then
   local ap,bp=source.profiles(a,b)
   if not ap then
    M.counts.fallback=M.counts.fallback+1
    texio.write_nl('log',string.format('OUTLINE PROFILE FALLBACK %s U+%04X',f.fullname or f.name or '?',fence.delim.small_char))
    return old
   end
   local path={};local H=((1-t)*ha+t*hb)*scale
   for stroke=1,#ap[1].xs,2 do
    for i,v in ipairs(ap) do
     local x=((1-t)*v.xs[stroke]+t*bp[i].xs[stroke])*scale
     path[#path+1]=string.format('%.7f %.7f %s',x*sp_to_bp,(axis+v.z*H)*sp_to_bp,i==1 and 'm' or 'l')
    end
    for i=#ap,1,-1 do
     local v=ap[i];local x=((1-t)*v.xs[stroke+1]+t*bp[i].xs[stroke+1])*scale
     path[#path+1]=string.format('%.7f %.7f l',x*sp_to_bp,(axis+v.z*H)*sp_to_bp)
    end
    path[#path+1]='h'
   end
   M.counts.profile=M.counts.profile+1
   return replace(old,path,math.floor(((1-t)*a.advance+t*b.advance)*scale+.5),math.floor(axis+H/2+.5),math.floor(H/2-axis+.5),0)
  else
   local path={};local blended={}
   for i,c in ipairs(apath) do
    local cc={c[1]};for j=2,#c do cc[j]=(1-t)*c[j]+t*bpath[i][j] end;blended[i]=cc
   end
   local H=((1-t)*ha+t*hb)*scale
   local centre=((1-t)*(a.bounds[2]+a.bounds[4])+t*(b.bounds[2]+b.bounds[4]))/2*scale
   emit(blended,scale,scale,0,axis-centre,path)
   local width=math.floor(((1-t)*a.advance+t*b.advance)*scale+.5)
   M.counts.interpolated=M.counts.interpolated+1
   return replace(old,path,width,math.floor(axis+H/2+.5),math.floor(H/2-axis+.5),0)
  end
 end
 local diagonal,advance=source.diagonal(fd,spec,fence.delim.small_char,height)
 if diagonal then
  local path={};emit(diagonal,scale,scale,0,axis,path)
  M.counts.extrapolated=M.counts.extrapolated+1
  return replace(old,path,math.floor(advance*scale+.5),math.floor(axis+target/2+.5),math.floor(target/2-axis+.5),0)
 end
 local ok,path=pcall(native_outline,old,fd)
 if not ok then
  M.counts.fallback=M.counts.fallback+1
  texio.write_nl('log','finaldelim outline fallback: '..tostring(path))
  return old
 end
 if old.id==vl then M.counts.assembled=M.counts.assembled+1 else M.counts.outlined=M.counts.outlined+1 end
 return replace(old,path,old.width,old.height,old.depth,old.shift)
end
luatexbase.add_to_callback('finish_pdffile',function()
 for k,v in pairs(M.counts) do texio.write_nl('log','OUTLINE '..k..' '..v) end
end,'finaldelim.outline.statistics')
return M
