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
 assert(#terms==#s)
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
local records=assert(io.open('build/width-integral.tsv','w'))
records:write('pattern\tn\tq\twidth\tleft\tright\tradius\n')
local geometry=assert(io.open('build/width-integral-geometry.tsv','w'))
geometry:write('pattern\tn\tW\tL\tH\tx\tfinish\tr\n')
local seen={}
function M.render(s,n,alpha,q)
 local t=M.results[s..n]
 local r,left,right
 if q==0 then r,left,right=estimate(t,alpha,3) else r,left,right=integral(t,alpha,3,q) end
 records:write(string.format('%s\t%d\t%d\t%.9f\t%.9f\t%.9f\t%.9f\n',s,n,q,t.W/65536,left/65536,right/65536,r/65536))
 if not seen[s..n] then
  for _,v in ipairs(t.terms) do geometry:write(string.format('%s\t%d\t%.12f\t%.12f\t%.12f\t%.12f\t%.12f\t%.12f\n',s,n,t.W/65536,t.L/65536,t.H/65536,v.x/65536,v.finish/65536,v.r/65536)) end
  seen[s..n]=true
 end
 tex.sprint(string.format('\\Cell{%d}{%.2f}',math.floor(r+.5),r/65536))
end
function M.check()
 for _,t in pairs(M.results) do
  local prev=t.L
  for _,q in ipairs({2,4,8,16}) do
   local r=integral(t,.5,3,q)
   assert(r>=prev-1e-6 and r<=t.H+1e-6); prev=r
   local split={W=t.W,L=t.L,H=t.H,terms={}}
   local mirror={W=t.W,L=t.L,H=t.H,terms={}}
   for _,v in ipairs(t.terms) do
    local mid=(v.x+v.finish)/2
    table.insert(split.terms,{x=v.x,finish=mid,r=v.r})
    table.insert(split.terms,{x=mid,finish=v.finish,r=v.r})
    table.insert(mirror.terms,1,{x=t.W-v.finish,finish=t.W-v.x,r=v.r})
   end
   assert(math.abs(r-integral(split,.5,3,q))<1e-6,'Subdivision changed size')
   local rr,rl,rt=integral(mirror,.5,3,q)
   local _,ol,ot=integral(t,.5,3,q)
   assert(math.abs(r-rr)<1e-6 and math.abs(rl-ot)<1e-6 and math.abs(rt-ol)<1e-6)
  end
 end
 local uniform={W=100,L=10,H=10,terms={{x=0,finish=100,r=10}}}
 assert(math.abs(integral(uniform,.5,3,4)-10)<1e-10)
 records:close(); geometry:close()
end
return M
