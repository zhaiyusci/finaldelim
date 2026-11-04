local axis=tex.dimen.mathaxis
local function radius(box) return math.max(box.height-axis,box.depth+axis) end
local H,L=radius(tex.box.highbox),radius(tex.box.lowbox)
texio.write_nl(string.format('WIDTHS %s %s %s',tex.box.highbox.width,tex.box.lowbox.width,tex.dimen.slotwidth))
assert(tex.box.highbox.width<=tex.dimen.slotwidth and tex.box.lowbox.width<=tex.dimen.slotwidth)
local patterns={'hhll','hlhl','hllh','lhhl','lhlh','llhh'}
local results={}
tex.sprint(string.format('\\noindent Measured radii: $H=%.2f$\\,pt; $L=%.2f$\\,pt.\\par\\medskip',H/65536,L/65536))
tex.sprint('\\begin{tabular}{@{}l*{4}{p{59mm}}@{}}')
tex.sprint('Pattern & \\centering Native: $H$ & \\centering Geometric: $\\sqrt{EH}$ & \\centering Arithmetic: $(E+H)/2$ & \\centering Distance-weighted \\tabularnewline[4pt]')
for _,s in ipairs(patterns) do
 local radii={}
 for i=1,4 do radii[i]=s:sub(i,i)=='h' and H or L end
 local E=math.max(radii[1],radii[4])
 local R=L
 for i=1,4 do R=math.max(R,L+(radii[i]-L)*math.exp(-math.min(i-1,4-i))) end
 local vals={H,math.sqrt(E*H),(E+H)/2,R}
 results[s]=vals
 local tokens=''
 for i=1,4 do tokens=tokens..'{'..s:sub(i,i)..'}' end
 tex.sprint('\\texttt{'..s..'}')
 for _,v in ipairs(vals) do
  tex.sprint(string.format('&\\Cell{%s}{%d}{%.2f}',tokens,math.floor(v+.5),v/65536))
 end
 tex.sprint('\\tabularnewline[5pt]')
 texio.write_nl('term and log',string.format('PATTERN %s: %.5f %.5f %.5f %.5f',s,vals[1]/65536,vals[2]/65536,vals[3]/65536,vals[4]/65536))
end
tex.sprint('\\end{tabular}')
for s,vals in pairs(results) do
 local mirror=s:reverse()
 for i=1,4 do assert(math.abs(vals[i]-results[mirror][i])<1e-6,'Mirror asymmetry') end
 if s~='lhhl' then
  for i=2,4 do assert(math.abs(vals[i]-H)<1e-6,'Endpoint constraint failed') end
 end
end
assert(results.lhhl[4]<H and results.lhhl[4]>L)
