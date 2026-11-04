local M={results={}}
local markerid=0x4E4D
function M.mark(i)
 local n=node.new('whatsit','user_defined'); n.user_id,n.type,n.value=markerid,100,i; node.write(n)
end
function M.source(s)
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
function M.row(s)
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
 local left,right=L,L
 local start,finish=terms[1].x,terms[#terms].finish
 for _,t in ipairs(terms) do
  t.dl,t.dr=t.x-start,finish-t.finish
  left=math.max(left,L+(t.r-L)*math.exp(-t.dl/lambda))
  right=math.max(right,L+(t.r-L)*math.exp(-t.dr/lambda))
 end
 local values={H,math.max(left,right),math.sqrt(left*right),(left+right)/2,math.sqrt((left*left+right*right)/2)}
 M.results[s]={left=left,right=right,values=values,width=b.width}
 tex.sprint(string.format('\\texttt{%s}\\par{\\scriptsize $R_L=%.2f$\\par $R_R=%.2f$}',s,left/65536,right/65536))
 for _,v in ipairs(values) do tex.sprint(string.format('&\\Cell{%d}{%.2f}',math.floor(v+.5),v/65536)) end
 tex.sprint('\\tabularnewline[5pt]')
 texio.write_nl('term and log',string.format('NATURAL %s left=%.5f right=%.5f geo=%.5f arith=%.5f rms=%.5f',s,left/65536,right/65536,values[3]/65536,values[4]/65536,values[5]/65536))
 for i,t in ipairs(terms) do texio.write_nl('term and log',string.format('TERM %s %d left=%.5f right=%.5f radius=%.5f',s,i,t.dl/65536,t.dr/65536,t.r/65536)) end
end
function M.check()
 for s,v in pairs(M.results) do
  local m=M.results[s:reverse()]
  assert(math.abs(v.left-m.right)<2 and math.abs(v.right-m.left)<2,'Mirror mismatch')
  assert(v.values[3]<=v.values[4]+1 and v.values[4]<=v.values[5]+1 and v.values[5]<=v.values[2]+1)
 end
end
return M
