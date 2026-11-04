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
function M.header()
 tex.sprint('\\begin{tabular}{@{}p{23mm}*{5}{p{66mm}}@{}}')
 tex.sprint('Pattern & \\centering Native $H$ & \\centering Side maximum & \\centering Geometric & \\centering Arithmetic & \\centering RMS \\tabularnewline[4pt]')
end
function M.row(s,n)
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
 local lambdas={tex.dimen.decaylength,W/4,W/2,W}
 local labels={'Fixed: $4\\,\\mathrm{em}$','Relative: $W/4$','Relative: $W/2$','Relative: $W$'}
 local values={}
 for k,lambda in ipairs(lambdas) do
  local left,right=L,L
  for _,t in ipairs(terms) do
   left=math.max(left,L+(t.r-L)*math.exp(-(t.x-start)/lambda))
   right=math.max(right,L+(t.r-L)*math.exp(-(finish-t.finish)/lambda))
  end
  values[k]=math.sqrt((left*left+right*right)/2)
 end
 M.results[s..n]={W=W,H=H,L=L,values=values}
 tex.sprint(string.format('\\par\\medskip\\textbf{Low block: %d terms}\\quad $W=%.2f$\\,pt; $H=%.2f$\\,pt, $L=%.2f$\\,pt.\\par\\smallskip',2*n,W/65536,H/65536,L/65536))
 tex.sprint('\\begin{tabular}{@{}p{176mm}p{176mm}@{}}')
 for k,v in ipairs(values) do
  tex.sprint('\\centering '..labels[k]..'\\par\\smallskip')
  tex.sprint(string.format('\\Cell{%d}{%.2f}',math.floor(v+.5),v/65536))
  if k==1 or k==3 then tex.sprint('&') else tex.sprint('\\tabularnewline[5pt]') end
 end
 tex.sprint('\\end{tabular}')
 texio.write_nl('term and log',string.format('DECAY %s %d W=%.5f H=%.5f L=%.5f fixed=%.5f quarter=%.5f half=%.5f full=%.5f',s,n,W/65536,H/65536,L/65536,values[1]/65536,values[2]/65536,values[3]/65536,values[4]/65536))
end
function M.check()
 for _,s in ipairs({'lhl','hml','hllh'}) do
  local prev=0
  for _,n in ipairs({1,3,6}) do
   local r=M.results[s..n]
   assert(r.W>prev); prev=r.W
   assert(r.values[2]<=r.values[3] and r.values[3]<=r.values[4])
   assert(math.abs(r.H-M.results[s..1].H)<2 and math.abs(r.L-M.results[s..1].L)<2)
   if s=='hllh' then for _,v in ipairs(r.values) do assert(math.abs(v-r.H)<2) end end
  end
 end
end
return M
