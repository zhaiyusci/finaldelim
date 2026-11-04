local M={results={}}
local markerid=0x4E4D
function M.mark(i)
 local n=node.new('whatsit','user_defined'); n.user_id,n.type,n.value=markerid,100,i; node.write(n)
end
function M.source(s,n)
 local low={}; for i=1,n do low[i]="a+b" end
 tex.sprint("\\def\\Low{"..table.concat(low,"+").."}")
 local parts={}; local names={h='High',m='Medium',l='Low'}
 for i=1,#s do parts[i]='\\Mark{'..i..'}\\'..names[s:sub(i,i)]..'\\Mark{0}' end
 tex.sprint('\\def\\Body{'..table.concat(parts,'+')..'}')
 local plain={}; for i=1,#s do plain[i]='\\'..names[s:sub(i,i)] end
 tex.sprint('\\def\\Unmarked{'..table.concat(plain,'+')..'}')
end
function M.measure(s,n)
 local b=tex.box.naturalbody
 local x,active,terms=0,nil,{}
 for n in node.traverse(b.list) do
  if n.id==node.id('whatsit') and n.subtype==node.subtype('user_defined') and n.user_id==markerid then
   active=n.value>0 and n.value or nil
   if active then terms[active]={h=0,d=0} end
  else
   local width=n.width or 0
   if n.id==node.id('kern') then width=n.kern elseif n.id==node.id('glue') then width=node.effective_glue(n,b) end
   if active and (n.id==node.id('glyph') or n.id==node.id('hlist') or n.id==node.id('vlist') or n.id==node.id('rule')) then
    local t=terms[active]; t.x=t.x or x; t.finish=x+width
    local shift=(n.id==node.id('hlist') or n.id==node.id('vlist')) and n.shift or 0
    t.h=math.max(t.h,n.height-shift); t.d=math.max(t.d,n.depth+shift)
   end
   x=x+width
  end
 end
 assert(#terms==M.expected)
 local axis,lambda=tex.dimen.mathaxis,tex.dimen.decaylength
 local L,H=math.huge,0
 for _,t in ipairs(terms) do
  assert(t.x and t.finish)
  t.r=math.max(t.h-axis,t.d+axis); L=math.min(L,t.r); H=math.max(H,t.r)
 end

 local start,finish=terms[1].x,terms[#terms].finish
 local W=b.width

 M.results[s..n]={terms=terms,W=W,H=H,L=L,start=start,finish=finish}
end
local function estimate(t,alpha,p)
 local left,right=t.L,t.L
 for _,v in ipairs(t.terms) do
  left=math.max(left,t.L+(v.r-t.L)*math.exp(-(v.x-t.start)/(alpha*t.W)))
  right=math.max(right,t.L+(v.r-t.L)*math.exp(-(t.finish-v.finish)/(alpha*t.W)))
 end
 local mx=math.max(left,right)
 local r=p==0 and mx or mx*(((left/mx)^p+(right/mx)^p)/2)^(1/p)
 return r,left,right
end

local function integral(t,alpha,p,q)
 if q==0 then return t.H,t.H,t.H end
 local lambda=alpha*t.W
 local norm=1-math.exp(-t.W/lambda)
 local floor=(t.L/t.H)^q
 local left,right=floor*norm,floor*norm
 local last=0
 for _,v in ipairs(t.terms) do
  assert(v.x>=last-0.01 and v.finish<=t.W+0.01)
  last=v.finish
  local excess=(v.r/t.H)^q-floor
  left=left+excess*(math.exp(-v.x/lambda)-math.exp(-v.finish/lambda))
  right=right+excess*(math.exp(-(t.W-v.finish)/lambda)-math.exp(-(t.W-v.x)/lambda))
 end
 left=t.H*(left/norm)^(1/q); right=t.H*(right/norm)^(1/q)
 return ((left^p+right^p)/2)^(1/p),left,right
end

local out=assert(io.open('build/parameter-grid.tsv','w'))
out:write('case\talpha\tq\tleft\tright\tradius\n')
local geo=assert(io.open('build/parameter-grid-geometry.tsv','w'))
geo:write('case\tW\tL\tH\tx\tfinish\tr\n')
function M.save(id,count)
 M.expected=count; M.measure(id,0)
 local t=M.results[id..0]; M.current=t; M.id=id
 for _,v in ipairs(t.terms) do geo:write(string.format('%s\t%.12f\t%.12f\t%.12f\t%.12f\t%.12f\t%.12f\n',id,t.W/65536,t.L/65536,t.H/65536,v.x/65536,v.finish/65536,v.r/65536)) end
end
function M.cell(alpha,q)
 local t=M.current
 local r,l,rr=integral(t,alpha,3,q)
 assert(r>=t.L-1e-6 and r<=t.H+1e-6)
 local split={W=t.W,L=t.L,H=t.H,terms={}}
 local mirror={W=t.W,L=t.L,H=t.H,terms={}}
 for _,v in ipairs(t.terms) do
  local m=(v.x+v.finish)/2
  table.insert(split.terms,{x=v.x,finish=m,r=v.r}); table.insert(split.terms,{x=m,finish=v.finish,r=v.r})
  table.insert(mirror.terms,1,{x=t.W-v.finish,finish=t.W-v.x,r=v.r})
 end
 assert(math.abs(r-integral(split,alpha,3,q))<1e-6)
 local mr,ml,mrr=integral(mirror,alpha,3,q)
 assert(math.abs(r-mr)<1e-6 and math.abs(l-mrr)<1e-6 and math.abs(rr-ml)<1e-6)
 out:write(string.format('%s\t%g\t%d\t%.9f\t%.9f\t%.9f\n',M.id,alpha,q,l/65536,rr/65536,r/65536))
 tex.sprint(string.format('\\Cell{%d}{%.2f}{%.2f}{%.2f}',math.floor(r+.5),l/65536,rr/65536,r/65536))
end
function M.close() out:close(); geo:close() end
return M
