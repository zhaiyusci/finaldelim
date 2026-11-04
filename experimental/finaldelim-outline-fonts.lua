-- Font-independent source for the outline-v1 renderer. Loaded lazily from luaotfload.
local M={version='outline-v1',cache={},specs={}}
local function convert(segments)
 local path,open={},false
 for _,s in ipairs(segments or {}) do
  local op=s[#s]
  if op=='m' then
   if open then path[#path+1]={'h'} end;open=true
  end
  if op=='m' or op=='l' or op=='c' then
   local c={op};for i=1,#s-1 do c[#c+1]=s[i] end;path[#path+1]=c
  else return nil end
 end
 if open then path[#path+1]={'h'} end
 return #path>0 and path or nil
end
local function bounds(path)
 local xmin,ymin,xmax,ymax=math.huge,math.huge,-math.huge,-math.huge
 local function add(x,y) xmin=math.min(xmin,x);xmax=math.max(xmax,x);ymin=math.min(ymin,y);ymax=math.max(ymax,y) end
 local x,y=0,0
 for _,c in ipairs(path) do
  if c[1]=='m' or c[1]=='l' then x,y=c[2],c[3];add(x,y)
  elseif c[1]=='c' then
   local p={x,y};add(c[6],c[7])
   for axis=1,2 do
    local p0,p1,p2,p3=p[axis],c[axis+1],c[axis+3],c[axis+5]
    local a=-p0+3*p1-3*p2+p3;local b=2*(p0-2*p1+p2);local cc=p1-p0
    local roots={}
    if math.abs(a)<1e-12 then if math.abs(b)>1e-12 then roots[1]=-cc/b end
    elseif b*b-4*a*cc>=0 then local d=math.sqrt(b*b-4*a*cc);roots={(-b+d)/(2*a),(-b-d)/(2*a)} end
    for _,t in ipairs(roots) do if t>0 and t<1 then
     local u=1-t
     add(u^3*x+3*u*u*t*c[2]+3*u*t*t*c[4]+t^3*c[6],u^3*y+3*u*u*t*c[3]+3*u*t*t*c[5]+t^3*c[7])
    end end
   end
   x,y=c[6],c[7]
  end
 end
 return {xmin,ymin,xmax,ymax}
end
local function compatible(a,b)
 if #a~=#b then return false end
 for i,c in ipairs(a) do if #c~=#b[i] or c[1]~=b[i][1] then return false end end
 return true
end
function M.compatible(a,b)
 if not compatible(a.path,b.path) then return false end
 local aw,ah=a.bounds[3]-a.bounds[1],a.bounds[4]-a.bounds[2]
 local bw,bh=b.bounds[3]-b.bounds[1],b.bounds[4]-b.bounds[2]
 if math.min(aw,ah,bw,bh)<=0 then return false end
 -- Matching operators alone do not establish corresponding control points.
 -- Reject reordered or differently anchored paths using normalized endpoints.
 for i,c in ipairs(a.path) do
  if #c>1 then
   local d=b.path[i]
   local ax,ay=(c[#c-1]-a.bounds[1])/aw,(c[#c]-a.bounds[2])/ah
   local bx,by=(d[#d-1]-b.bounds[1])/bw,(d[#d]-b.bounds[2])/bh
   if math.abs(ax-bx)>.25 or math.abs(ay-by)>.25 then return false end
  end
 end
 return true
end
local function edges(path)
 local result={};local x,y,sx,sy
 local function line(nx,ny) if x and y~=ny then result[#result+1]={x,y,nx,ny} end;x,y=nx,ny end
 for _,c in ipairs(path) do
  if c[1]=='m' then x,y,sx,sy=c[2],c[3],c[2],c[3]
  elseif c[1]=='l' then line(c[2],c[3])
  elseif c[1]=='c' then
   local x0,y0=x,y
   for j=1,96 do local t=j/96;local u=1-t;line(u^3*x0+3*u*u*t*c[2]+3*u*t*t*c[4]+t^3*c[6],u^3*y0+3*u*u*t*c[3]+3*u*t*t*c[5]+t^3*c[7]) end
  elseif c[1]=='h' then line(sx,sy) end
 end
 return result
end
-- Match closed contours by normalized perimeter, not by font control-point count.
-- Include both sets of vertices in the shared grid so corners are never skipped.
function M.contours(a,b)
 local function flatten(g)
  local contours,points={},nil
  local x,y
  local function add(nx,ny)
   if not points or #points==0 or nx~=x or ny~=y then points[#points+1]={nx,ny} end
   x,y=nx,ny
  end
  for _,c in ipairs(g.path) do
   if c[1]=='m' then points={};contours[#contours+1]=points;add(c[2],c[3])
   elseif c[1]=='l' then add(c[2],c[3])
   elseif c[1]=='c' then
    local x0,y0=x,y
    for j=1,96 do local t=j/96;local u=1-t
     add(u^3*x0+3*u*u*t*c[2]+3*u*t*t*c[4]+t^3*c[6],u^3*y0+3*u*u*t*c[3]+3*u*t*t*c[5]+t^3*c[7])
    end
   end
  end
  return contours
 end
 local ac,bc=flatten(a),flatten(b)
 if #ac~=#bc then return nil end
 -- Font variants may reorder independent contours (e.g. the two angle strokes).
 -- Pair by geometric position before comparing their normalized shapes.
 local function order(contours)
  local keys={}
  for _,ps in ipairs(contours) do
   local x0,y0,x1,y1=math.huge,math.huge,-math.huge,-math.huge
   for _,p in ipairs(ps) do x0=math.min(x0,p[1]);x1=math.max(x1,p[1]);y0=math.min(y0,p[2]);y1=math.max(y1,p[2]) end
   keys[ps]={x0+x1,y0+y1,x1-x0,y1-y0}
  end
  table.sort(contours,function(p,q)
   for i=1,4 do if keys[p][i]~=keys[q][i] then return keys[p][i]<keys[q][i] end end
   return false
  end)
 end
 order(ac);order(bc)
 local function parameterize(points,g)
  local w,h=g.bounds[3]-g.bounds[1],g.bounds[4]-g.bounds[2]
  if w<=0 or h<=0 then return nil end
  local ts={0};local total=0
  for i=2,#points+1 do
   local p,q=points[i-1],points[i] or points[1]
   total=total+math.sqrt(((q[1]-p[1])/w)^2+((q[2]-p[2])/h)^2);ts[i]=total
  end
  if total==0 then return nil end
  for i=1,#ts do ts[i]=ts[i]/total end
  return ts
 end
 local function sample(points,ts,t)
  local i=1;while i<#ts-1 and ts[i+1]<t do i=i+1 end
  local p,q=points[i],points[i+1] or points[1]
  local u=ts[i+1]==ts[i] and 0 or (t-ts[i])/(ts[i+1]-ts[i])
  return {p[1]+u*(q[1]-p[1]),p[2]+u*(q[2]-p[2])}
 end
 local ap,bp={},{}
 local function anchor(points)
  local best=1
  for i,p in ipairs(points) do local q=points[best]
   if p[2]<q[2] or (p[2]==q[2] and p[1]<q[1]) then best=i end
  end
  local result={};for i=1,#points do result[i]=points[(best+i-2)%#points+1] end
  return result
 end
 for k,ps in ipairs(ac) do
  ps=anchor(ps)
  local qs=bc[k]
  local function area(points)
   local sum=0;for i,p in ipairs(points) do local q=points[i%#points+1];sum=sum+p[1]*q[2]-q[1]*p[2] end
   return sum
  end
  if area(ps)*area(qs)<0 then
   local reversed={};for i=#qs,1,-1 do reversed[#reversed+1]=qs[i] end;qs=reversed
  end
  -- Use a geometric anchor independent of the font contour starting vertex.
  qs=anchor(qs)
  local ats,bts=parameterize(ps,a),parameterize(qs,b)
  if not ats or not bts then return nil end
  local grid={};for _,t in ipairs(ats) do grid[#grid+1]=t end
  for _,t in ipairs(bts) do grid[#grid+1]=t end;table.sort(grid)
  local prev
  for _,t in ipairs(grid) do if t<1 and (not prev or t-prev>1e-12) then
   local p,q=sample(ps,ats,t),sample(qs,bts,t)
   -- Do not silently match reordered contours or unrelated starting anchors.
   for axis=1,2 do
    local pa=(p[axis]-a.bounds[axis])/(a.bounds[axis+2]-a.bounds[axis])
    local pb=(q[axis]-b.bounds[axis])/(b.bounds[axis+2]-b.bounds[axis])
    if math.abs(pa-pb)>.12 then return nil end
   end
   local op=prev and 'l' or 'm'
   ap[#ap+1]={op,p[1],p[2]};bp[#bp+1]={op,q[1],q[2]};prev=t
  end end
  ap[#ap+1]={'h'};bp[#bp+1]={'h'}
 end
 return ap,bp
end
-- Shared normalized-height grid; retain separate strokes rather than filling gaps.
function M.profiles(a,b)
 local key=tostring(a)..':'..tostring(b)
 M.profile_cache=M.profile_cache or {}
 if M.profile_cache[key]~=nil then return table.unpack(M.profile_cache[key]) end
 local grid={};for i=0,1024 do grid[#grid+1]=i/1024-.5 end
 for _,g in ipairs{a,b} do
  local H=g.bounds[4]-g.bounds[2];local centre=(g.bounds[4]+g.bounds[2])/2
  for _,c in ipairs(g.path) do if #c>1 then grid[#grid+1]=math.max(-.5,math.min(.5,(c[#c]-centre)/H)) end end
 end
 table.sort(grid);local zs={};for _,z in ipairs(grid) do if #zs==0 or z-zs[#zs]>1e-10 then zs[#zs+1]=z end end
 local results={};local nintervals
 for _,g in ipairs{a,b} do
  local es=edges(g.path);local H=g.bounds[4]-g.bounds[2];local centre=(g.bounds[4]+g.bounds[2])/2;local profile={}
  for _,z in ipairs(zs) do
   -- Use a tiny inward shift at extrema to avoid an empty tangent section.
   local y=centre+math.max(-.5+1e-6,math.min(.5-1e-6,z))*H;local xs={}
   for _,e in ipairs(es) do
    if (e[2]<=y and e[4]>y) or (e[4]<=y and e[2]>y) then xs[#xs+1]=e[1]+(y-e[2])*(e[3]-e[1])/(e[4]-e[2]) end
   end
   table.sort(xs)
   if #xs<2 or #xs%2~=0 or (nintervals and #xs~=nintervals) then M.profile_cache[key]={false};return false end
   nintervals=nintervals or #xs
   profile[#profile+1]={z=z,xs=xs}
  end
  results[#results+1]=profile
 end
 M.profile_cache[key]=results;return table.unpack(results)
end
function M.diagonal(fd,spec,code,H)
 if code==0x27ea or code==0x27eb then
  -- Treat the two strokes independently, retaining their source offsets.
  -- Their spacing is not multiplied by the requested height.
  local parts={{glyphs={}},{glyphs={}}};local specs={{variants={}},{variants={}}}
  for _,id in ipairs(spec.variants) do
   local g=fd.glyphs[id];local contours={};local path
   for _,c in ipairs(g.path) do
    if c[1]=='m' then path={};contours[#contours+1]=path end
    if path then path[#path+1]=c end
   end
   if #contours~=2 then return nil end
   local gs={}
   for _,p in ipairs(contours) do gs[#gs+1]={path=p,bounds=bounds(p),advance=g.advance} end
   table.sort(gs,function(a,b) return a.bounds[1]+a.bounds[3]<b.bounds[1]+b.bounds[3] end)
   for j=1,2 do parts[j].glyphs[id]=gs[j];specs[j].variants[#specs[j].variants+1]=id end
  end
  local id=spec.variants[#spec.variants];local g=fd.glyphs[id];local b=g.bounds
  local delta=H-(b[4]-b[2]);if delta<=0 then return nil end
  local result={};local drawn={}
  for j=1,2 do
   local p=parts[j].glyphs[id].bounds
   local path=M.diagonal(parts[j],specs[j],code==0x27ea and 0x27e8 or 0x27e9,p[4]-p[2]+delta)
   if not path then return nil end
   local shift=(p[2]+p[4]-b[2]-b[4])/2
   for _,c in ipairs(path) do if #c>1 then c[3]=c[3]+shift end end
   drawn[j]=path
  end
  local function center(path,y)
   local hits={}
   for _,e in ipairs(edges(path)) do
    if (e[2]<=y and e[4]>y) or (e[4]<=y and e[2]>y) then hits[#hits+1]=e[1]+(y-e[2])*(e[3]-e[1])/(e[4]-e[2]) end
   end
   if #hits~=2 then return nil end
   return (hits[1]+hits[2])/2
  end
  local ref=(b[2]+b[4])/2+(b[4]-b[2])/4
  local original1=center(parts[1].glyphs[id].path,ref)
  local original2=center(parts[2].glyphs[id].path,ref)
  local new1,new2=center(drawn[1],H/4),center(drawn[2],H/4)
  if not original1 or not original2 or not new1 or not new2 then return nil end
  local correction=(original2-original1)-(new2-new1)
  for _,c in ipairs(drawn[2]) do if #c>1 then c[2]=c[2]+correction end end
  for j=1,2 do for _,c in ipairs(drawn[j]) do result[#result+1]=c end end
  local bb=bounds(result)
  return result,g.advance+(bb[3]-bb[1])-(b[3]-b[1])
 end
 local angle=code==0x27e8 or code==0x27e9
 if not angle and code~=47 and code~=92 then return nil end
 local g=fd.glyphs[spec.variants[#spec.variants]]
 local box=g.bounds;local h=box[4]-box[2];local w=box[3]-box[1]
 if H<=h then return nil end
 local cy=(box[2]+box[4])/2
 local es=edges(g.path);local ys,xs={},{};local stroke=0
 for i=0,32 do
  local y=box[2]+h*(.60+.25*i/32);local hits={}
  for _,e in ipairs(es) do
   if (e[2]<=y and e[4]>y) or (e[4]<=y and e[2]>y) then
    hits[#hits+1]=e[1]+(y-e[2])*(e[3]-e[1])/(e[4]-e[2])
   end
  end
  if #hits~=2 then return nil end
  stroke=math.max(stroke,math.abs(hits[1]-hits[2]))
  ys[#ys+1]=y-cy;xs[#xs+1]=(hits[1]+hits[2])/2
 end
 local function regression(x,y)
  local ax,ay=0,0;for i=1,#x do ax=ax+x[i];ay=ay+y[i] end
  ax=ax/#x;ay=ay/#x;local num,den=0,0
  for i=1,#x do num=num+(x[i]-ax)*(y[i]-ay);den=den+(x[i]-ax)^2 end
  return den>0 and num/den or 0,ax,ay
 end
 local slope,ym,xm=regression(ys,xs);local intercept=xm-slope*ym
 if math.abs(slope)<1e-6 then return nil end
 local hs,ws={},{}
 for i=math.max(1,#spec.variants-2),#spec.variants do
  local b=fd.glyphs[spec.variants[i]].bounds
  hs[#hs+1]=b[4]-b[2];ws[#ws+1]=b[3]-b[1]
 end
 local growth=math.abs(slope)*(angle and .5 or 1)
 if #hs>1 then local trend=regression(hs,ws);growth=math.max(0,trend) end
 local W=w+growth*(H-h);local sy=H/h
 -- Protect terminal and vertex neighborhoods in absolute font units. Only
 -- the straight middle sections absorb added height, avoiding long needle tips.
 local cap=math.min(h*.15,2*stroke)
 local function extend_y(y)
  local sign=y<0 and -1 or 1;local t=math.abs(y);local start=angle and cap or 0
  local stop=h/2-cap;local extra=(H-h)/2
  if t>=stop then return y+sign*extra end
  if t<=start then return y end
  return sign*(t+extra*(t-start)/(stop-start))
 end
 -- Retain the original terminals and vertex, flattening curves only for the
 -- piecewise centerline map. Normal stroke thickness is independent of growth.
 local points={};local x,y
 for _,c in ipairs(g.path) do
  if c[1]=='m' or c[1]=='l' then x,y=c[2],c[3];points[#points+1]={c[1],x,y}
  elseif c[1]=='c' then
   local x0,y0=x,y
   for j=1,96 do local t=j/96;local u=1-t
    points[#points+1]={'l',u^3*x0+3*u*u*t*c[2]+3*u*t*t*c[4]+t^3*c[6],u^3*y0+3*u*u*t*c[3]+3*u*t*t*c[5]+t^3*c[7]}
   end
   x,y=c[6],c[7]
  else points[#points+1]={'h'} end
 end
 local function mapped(k,output)
  local ratio=math.sqrt(1+(slope*k/sy)^2)/math.sqrt(1+slope^2)
  local lo,hi=math.huge,-math.huge;local path={}
  for _,p in ipairs(points) do
   if #p==1 then path[#path+1]={'h'} else
    local yy=p[3]-cy;local center=intercept+slope*(angle and math.abs(yy) or yy)
    local newy=extend_y(yy)
    local newcenter=intercept+slope*k/sy*(angle and math.abs(newy) or newy)
    local xx=newcenter+ratio*(p[2]-center)
    lo=math.min(lo,xx);hi=math.max(hi,xx)
    if output then path[#path+1]={p[1],xx,newy} end
   end
  end
  if output then for _,p in ipairs(path) do if #p>1 then p[2]=p[2]-lo+box[1] end end end
  return hi-lo,path
 end
 local low,high=0,math.max(2,W/w*2)
 if mapped(low)>W then return nil end
 while mapped(high)<W do high=high*2 end
 for i=1,48 do local mid=(low+high)/2;if mapped(mid)<W then low=mid else high=mid end end
 local _,path=mapped((low+high)/2,true)
 return path,g.advance+W-w
end
function M.get(f,code)
 local filename=f.filename or (f.properties and f.properties.filename)
 if not filename then return nil,'no outline file' end
 -- Transformed/variable faces need their transformed outlines, not the base face.
 if (f.extend and f.extend~=0 and f.extend~=1000) or (f.slant and f.slant~=0) or (f.squeeze and f.squeeze~=0 and f.squeeze~=1000) then return nil,'transformed font' end
 local features=f.specification and f.specification.features and f.specification.features.normal
 if features and (features.axis or features.instance) then return nil,'variable instance not supported' end
 local sub=(f.subfont or (f.properties and f.properties.subfont))
 local key=filename..':'..tostring(sub or '')
 local fd=M.cache[key]
 if fd==nil then
  local readers=fonts and fonts.handlers and fonts.handlers.otf and fonts.handlers.otf.readers
  if not readers or not readers.loadshapes then return nil,'outline reader unavailable' end
  local ok,raw=pcall(readers.loadshapes,filename,sub)
  if not ok or not raw or not raw.glyphs or not raw.units or raw.units<=0 then M.cache[key]=false;return nil,'outline load failed' end
  fd={units=raw.units,glyphs={}}
  setmetatable(fd.glyphs,{__index=function(t,id)
   local g=raw.glyphs[id];local path=g and convert(g.segments)
   if not path then return nil end
   local value={path=path,bounds=bounds(path),advance=g.width or 0}
   rawset(t,id,value);return value
  end})
  M.cache[key]=fd
  texio.write_nl('log','OUTLINE FONT '..filename)
 end
 if not fd then return nil,'outline load failed' end
 local specs=M.specs[f];if not specs then specs={};M.specs[f]=specs end
 if specs[code]==nil then
  local ch=f.characters[code];local ids,seen={},{};local assembly=false
  while ch do
   local id=ch.index
   if not id or seen[id] then break end;seen[id]=true
   local g=fd.glyphs[id]
   if not g then specs[code]=false;return nil,'glyph has no readable outline' end
   if g.bounds[4]>g.bounds[2] then ids[#ids+1]=id end
   assembly=assembly or ch.vert_variants~=nil
   ch=ch.next and f.characters[ch.next]
  end
  table.sort(ids,function(i,j)
   local a,b=fd.glyphs[i].bounds,fd.glyphs[j].bounds
   local ha,hb=a[4]-a[2],b[4]-b[2]
   return ha==hb and i<j or ha<hb
  end)
  specs[code]=#ids>0 and {variants=ids,assembly=assembly} or false
 end
 if not specs[code] then return nil,'no delimiter outline' end
 return fd,specs[code]
end
return M
