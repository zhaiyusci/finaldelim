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
local records=assert(io.open('build/power-means.tsv','w'))
records:write('pattern\tn\talpha\tp\twidth\tleft\tright\tradius\n')
function M.render(s,n,alpha,p)
 local t=M.results[s..n]
 local r,left,right=estimate(t,alpha,p)
 records:write(string.format('%s\t%d\t%g\t%d\t%.6f\t%.6f\t%.6f\t%.6f\n',s,n,alpha,p,t.W/65536,left/65536,right/65536,r/65536))
 tex.sprint(string.format('\\Cell{%d}{%.2f}',math.floor(r+.5),r/65536))
end
function M.check()
 for _,s in ipairs({'hml','lmh','lhl','hllh'}) do
  for _,n in ipairs({1,6}) do
   local t=M.results[s..n]
   for _,alpha in ipairs({.25,.5,1}) do
    local prev=0
    for _,p in ipairs({1,2,3,4,0}) do
     local r=estimate(t,alpha,p)
     assert(r+1>=prev and r<=t.H+1); prev=r
     if s=='hllh' then assert(math.abs(r-t.H)<2) end
     if s=='hml' then assert(math.abs(r-estimate(M.results['lmh'..n],alpha,p))<2) end
    end
   end
  end
 end
 records:close()
end
return M
