-- Optional continuous outline renderer.
local M={counts={interpolated=0,assembled=0,outlined=0,profile=0,fallback=0,extrapolated=0}}
local source=require('finaldelim-outline-fonts')
local output=require('finaldelim-output')
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
   elseif n.id==node.id('glue') then
    local amount=node.effective_glue(n,b)
    if n.leader then
     assert(not vertical and n.subtype==101,'Unsupported leader placement')
     local leader=n.leader;local width=leader.width
     assert(leader.id==hl and width>0,'Unsupported leader box')
     local count=math.floor((amount+10)/width)
     local offset=math.floor((amount-count*width)/2)
     for i=0,count-1 do walk(leader,cursor+offset+i*width,y-leader.shift) end
    end
    cursor=cursor+(vertical and -1 or 1)*amount
   elseif n.id==node.id('math') then cursor=cursor+(n.width or 0)
   else error('Unsupported node in native delimiter: '..node.type(n.id)) end
  end
 end
 walk(box,0,0)
 return out
end
local function replace(old,path,width,height,depth,shift)
 -- A single nonzero fill paints the union of overlapping, consistently wound parts.
 local n=output.literal('q\n'..table.concat(path,'\n')..'\nf\nQ')
 local box=node.new('hlist');box.dir=old.dir;box.list=n;box.width=width;box.height=height;box.depth=depth;box.shift=shift;box.attr=old.attr
 node.flush_node(old)
 return box
end
-- Lay out the font's vertical parts at the requested ink extent, rather than
-- reuse the size selected by TeX. Connector overlap is continuous; cap and
-- cusp outlines retain their original geometry. Parts run from bottom to top.
local function continuous_assembly(f,fd,spec,target,axis)
 if not spec.assembly then return end
 local scale=f.size/fd.units
 local minimum=(f.mathparameters or {}).MinConnectorOverlap or 0
 local extensible=false
 for _,p in ipairs(spec.assembly) do if p.extender==1 then extensible=true end end
 for repeats=0,4096 do
  local parts={}
  for _,p in ipairs(spec.assembly) do
   for _=1,p.extender==1 and repeats or 1 do parts[#parts+1]=p end
  end
  if #parts>0 then
   local gs,total,lo,hi={},0,0,0
   for i,p in ipairs(parts) do
    local ch=f.characters[p.glyph];local g=ch and fd.glyphs[ch.index]
    if not g then return end
    gs[i]={g=g,depth=ch.depth or 0};total=total+p.advance
    if i>1 then
     local overlap=math.min(parts[i-1]['end'],p.start)
     if overlap<minimum then return end
     lo=lo+minimum;hi=hi+overlap
    end
   end
   local bottom=gs[1].depth+gs[1].g.bounds[2]*scale
   local last=gs[#parts]
   total=total+last.depth+last.g.bounds[4]*scale-parts[#parts].advance-bottom
   if target>=total-hi-.01 and target<=total-lo+.01 then
    local t=hi==lo and 0 or math.max(0,math.min(1,(total-target-lo)/(hi-lo)))
    local out,pos,width={},axis-target/2-bottom,0
    for i,p in ipairs(parts) do
     local g=gs[i].g
     emit(g.path,scale,scale,0,pos+gs[i].depth,out)
     width=math.max(width,g.advance*scale)
     pos=pos+p.advance
     if parts[i+1] then
      local maxoverlap=math.min(p['end'],parts[i+1].start)
      pos=pos-minimum-t*(maxoverlap-minimum)
     end
    end
    return out,math.floor(width+.5)
   end
   if target<total-hi then return end
  end
  if not extensible then return end
 end
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
 -- Weighted sizing already includes the user's scale. Native delimiterfactor
 -- and delimitershortfall are glyph-selection tolerances, not another scale.
 local target=math.max(0,2*radius)
 local scale=f.size/fd.units
 local height=target/scale
 local lower,upper=spec.variants[1],nil
 for _,id in ipairs(spec.variants) do
  local b=fd.glyphs[id].bounds;local H=b[4]-b[2]
  if H>=height then upper=id;break end
  lower=id
 end
 local a=fd.glyphs[lower];local b=upper and fd.glyphs[upper]
 if lower==upper then
  local path={};local H=a.bounds[4]-a.bounds[2]
  emit(a.path,scale,target/H,0,axis-(a.bounds[2]+a.bounds[4])*target/H/2,path)
  M.counts.interpolated=M.counts.interpolated+1
  return replace(old,path,math.floor(a.advance*scale+.5),math.floor(axis+target/2+.5),math.floor(target/2-axis+.5),0)
 end
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
   local H=target
   local bounds=source.path_bounds(blended)
   local sy=target/(bounds[4]-bounds[2])
   emit(blended,scale,sy,0,axis-(bounds[2]+bounds[4])*sy/2,path)
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
 local assembled,width=continuous_assembly(f,fd,spec,target,axis)
 if assembled then
  M.counts.assembled=M.counts.assembled+1
  return replace(old,assembled,width,math.floor(axis+target/2+.5),math.floor(target/2-axis+.5),0)
 end
 -- Some fonts have a gap between their largest variant and the shortest
 -- legal assembly (notably STIX's bars). Bridge it with the last outline;
 -- also use this when a font provides no extender. Never snap back to a
 -- native size merely because no assembly covers the requested length.
 local path={};local sy=target/(a.bounds[4]-a.bounds[2])
 emit(a.path,scale,sy,0,axis-(a.bounds[2]+a.bounds[4])*sy/2,path)
 M.counts.extrapolated=M.counts.extrapolated+1
 return replace(old,path,math.floor(a.advance*scale+.5),math.floor(axis+target/2+.5),math.floor(target/2-axis+.5),0)
end

-- Radical drawing is deliberately downstream of native math layout. The
-- sign box, overbar, degree, scripts and radicand keep their native metrics.
M.counts.radicals=0
M.counts.radical_fallback=0
local radical_subtype
for k,v in pairs(node.subtypes('vlist')) do if v=='radical' then radical_subtype=k end end
local function radical_parts(f)
 local allowed,seen={},{}
 local ch=f.characters[0x221A]
 while ch and not seen[ch] do
  seen[ch]=true;allowed[ch.index]=true
  for _,part in ipairs(ch.vert_variants or {}) do
   local c=f.characters[part.glyph];if c then allowed[c.index]=true end
  end
  ch=ch.next and f.characters[ch.next]
 end
 return allowed
end
local function contour_direction(path)
 -- Signed area of sampled contours; the largest contour is an outer stroke.
 local best,area,x,y,sx,sy=0,0,0,0,0,0
 local function line(nx,ny) area=area+x*ny-nx*y;x,y=nx,ny end
 for _,c in ipairs(path) do
  if c[1]=='m' then area=0;x,y=c[2],c[3];sx,sy=x,y
  elseif c[1]=='l' then line(c[2],c[3])
  elseif c[1]=='c' then
   local ox,oy=x,y
   for i=1,16 do local t=i/16;local u=1-t
    line(u^3*ox+3*u*u*t*c[2]+3*u*t*t*c[4]+t^3*c[6],
         u^3*oy+3*u*u*t*c[3]+3*u*t*t*c[5]+t^3*c[7])
   end
  elseif c[1]=='h' then
   line(sx,sy);if math.abs(area)>math.abs(best) then best=area end
  end
 end
 return best>=0 and 1 or -1
end
local function draw_radical(sign,body)
 local first=first_glyph(sign.list)
 if not first then return end
 local f=font.getfont(first.font)
 local fd=source.get(f,0x221A)
 if not fd then return end
 local allowed=radical_parts(f)
 local valid=true
 local function check(head)
  for n in node.traverse(head) do
   if n.id==glyph then
    local c=f.characters[n.char]
    if n.font~=first.font or not c or not allowed[c.index] then valid=false end
   elseif n.id==hl or n.id==vl then check(n.list) end
  end
 end
 check(sign.list);if not valid then return end
 local y=body.height-body.shift+sign.shift
 local rule
 for n in node.traverse(body.list) do
  if n.id==node.id('kern') then y=y-n.kern
  elseif n.id==node.id('rule') then rule=n;break
  else return end
 end
 if not rule then return end
 local width=rule.width==-1073741824 and body.width or rule.width
 if width<=0 or rule.height<0 or rule.depth<0 then return end
 local ok,path=pcall(native_outline,sign,fd)
 if not ok then return end
 local x=sign.width
 local bottom=y-rule.height-rule.depth
 local points
 if contour_direction(fd.glyphs[f.characters[first.char].index].path)>0 then
  points={{'m',x,bottom},{'l',x+width,bottom},{'l',x+width,y},{'l',x,y},{'h'}}
 else
  points={{'m',x,bottom},{'l',x,y},{'l',x+width,y},{'l',x+width,bottom},{'h'}}
 end
 emit(points,1,1,0,0,path)
 -- Replacing the overbar by a same-height kern leaves all content positions
 -- unchanged, while sign and bar are now painted by a single fill operation.
 local skip=node.new('kern');skip.kern=rule.height+rule.depth
 body.list=node.insert_before(body.list,rule,skip)
 body.list=node.remove(body.list,rule);node.free(rule)
 M.counts.radicals=M.counts.radicals+1
 return path
end
function M.render_radicals(head)
 local n=head
 while n do
  if n.id==hl or n.id==vl then n.list=M.render_radicals(n.list) end
  local nextnode=n.next
  if (n.id==hl or n.id==vl) and nextnode and nextnode.id==vl
   and nextnode.subtype==radical_subtype then
   local path=draw_radical(n,nextnode)
   if path then
    local prev=n.prev
    local new=replace(n,path,n.width,n.height,n.depth,n.shift)
    new.prev,new.next=prev,nextnode;nextnode.prev=new
    if prev then prev.next=new else head=new end
   elseif first_glyph(n.list) then M.counts.radical_fallback=M.counts.radical_fallback+1 end
  end
  n=nextnode
 end
 return head
end

-- Horizontal stretch constructions retain the exact native boxes and positions.
-- Join font assemblies and amsmath's centered-leader arrow pieces in one fill.
local boxkind={}
for k,v in pairs(node.subtypes('hlist')) do boxkind[v]=k end
M.counts.horizontal=0;M.counts.accents=0;M.counts.leader_arrows=0
local arrowcodes={[0x2190]=true,[0x2192]=true,[0x2194]=true,
 [0x21D0]=true,[0x21D2]=true,[0x21D4]=true,[0x21A6]=true}
local function horizontal_candidate(box,accent)
 local first=first_glyph(box.list)
 if not first then return end
 local f=font.getfont(first.font)
 local pure,arrow,leaders=true,false,false
 local function scan(head)
  for n in node.traverse(head) do
   if n.id==glyph then
    if n.font~=first.font then pure=false end
    if arrowcodes[n.char] then arrow=true
    elseif n.char~=0x2212 and n.char~=0x3D then pure=false end
   elseif n.id==hl or n.id==vl then scan(n.list)
   elseif n.id==node.id('glue') and n.leader then leaders=true;scan(n.leader.list) end
  end
 end
 local kind
 if box.subtype==boxkind.hextensible then kind='horizontal'
 elseif accent and box.subtype==boxkind.mathchar then kind='accents'
 else
  scan(box.list)
  if pure and arrow and leaders then kind='leader_arrows' else return end
 end
 local fd=source.get(f,first.char)
 if not fd then return end
 -- In native font assemblies and accents every component must use the same
 -- outline source. Mixed-font constructions conservatively retain native ink.
 local same=true
 local function fonts(head)
  for n in node.traverse(head) do
   if n.id==glyph and n.font~=first.font then same=false
   elseif n.id==hl or n.id==vl then fonts(n.list) end
  end
 end
 fonts(box.list);if not same then return end
 local ok,path=pcall(native_outline,box,fd)
 if not ok then return end
 return path,kind
end
function M.render_horizontal(head,parent)
 local n=head
 while n do
  local nextnode=n.next
  if n.id==hl or n.id==vl then
   local path,kind=horizontal_candidate(n,parent and parent.subtype==boxkind.accent)
   if path then
    local prev=n.prev
    local new=replace(n,path,n.width,n.height,n.depth,n.shift)
    new.prev,new.next=prev,nextnode
    if nextnode then nextnode.prev=new end
    if prev then prev.next=new else head=new end
    M.counts[kind]=M.counts[kind]+1
   else n.list=M.render_horizontal(n.list,n) end
  end
  n=nextnode
 end
 return head
end
luatexbase.add_to_callback('post_mlist_to_hlist_filter',function(head)
 if tex.count.FinalDelimDrawing==1 then
  head=M.render_radicals(head)
  return M.render_horizontal(head)
 end
 return head
end,'finaldelim.radical.outlines')
luatexbase.add_to_callback('finish_pdffile',function()
 for k,v in pairs(M.counts) do texio.write_nl('log','OUTLINE '..k..' '..v) end
end,'finaldelim.outline.statistics')
return M
