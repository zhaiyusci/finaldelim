local axis=tex.dimen.mathaxis
local boxes={h=tex.box.highbox,m=tex.box.midbox,l=tex.box.lowbox}
local r={}
for k,b in pairs(boxes) do
 assert(b.width<=tex.dimen.slotwidth,'Slot too narrow')
 r[k]=math.max(b.height-axis,b.depth+axis)
end
assert(r.h>r.m and r.m>r.l)
local results={}
for page,patterns in ipairs({{'hml','hlm','mhl','mlh','lhm','lmh'}, {'hhll','hlhl','hllh','lhhl','lhlh','llhh'}}) do
 if page>1 then tex.sprint('\\newpage') end
 tex.sprint('\\Heading{'..(page==1 and 'Separate left/right estimates: h, m, l' or 'Revisiting the six h/l arrangements')..'}')
 tex.sprint(string.format('\\noindent Radii: $h=%.2f$, $m=%.2f$, $l=%.2f$\\,pt. Side estimates below each pattern are in pt.\\par\\medskip',r.h/65536,r.m/65536,r.l/65536))
 tex.sprint('\\begin{tabular}{@{}p{21mm}*{4}{p{59mm}}@{}}')
 tex.sprint('Pattern & \\centering Native: $H$ & \\centering Previous: $\\max(R_L,R_R)$ & \\centering Arithmetic mean & \\centering Geometric mean \\tabularnewline[4pt]')
 for _,s in ipairs(patterns) do
  local L,H=math.huge,0
  for i=1,#s do L=math.min(L,r[s:sub(i,i)]); H=math.max(H,r[s:sub(i,i)]) end
  local left,right=L,L
  local body={}
  for i=1,#s do
   local ri=r[s:sub(i,i)]
   left=math.max(left,L+(ri-L)*math.exp(-(i-1)))
   right=math.max(right,L+(ri-L)*math.exp(-(#s-i)))
   body[#body+1]='\\Slot{'..s:sub(i,i)..'}'
  end
  local vals={H,math.max(left,right),(left+right)/2,math.sqrt(left*right)}
  results[s]={left=left,right=right,vals=vals}
  tex.sprint(string.format('\\texttt{%s}\\par{\\scriptsize $R_L=%.2f$\\par $R_R=%.2f$}',s,left/65536,right/65536))
  for _,v in ipairs(vals) do tex.sprint(string.format('&\\Cell{%s}{%d}{%.2f}',table.concat(body,'\\kern\\slotgap'),math.floor(v+.5),v/65536)) end
  tex.sprint('\\tabularnewline[5pt]')
  texio.write_nl('term and log',string.format('TWOSIDE %s %.6f %.6f %.6f %.6f',s,left/65536,right/65536,vals[3]/65536,vals[4]/65536))
 end
 tex.sprint('\\end{tabular}\\Explanation')
end
for s,v in pairs(results) do
 local mirror=results[s:reverse()]
 assert(math.abs(v.left-mirror.right)<1e-6)
 for i=1,4 do assert(math.abs(v.vals[i]-mirror.vals[i])<1e-6) end
 assert(v.vals[4]<=v.vals[3]+1e-6 and v.vals[3]<=v.vals[2]+1e-6)
end
assert(results.hml.vals[3]<r.h)
assert(results.hllh.vals[3]==r.h)
assert(results.hhll.vals[3]<results.hlhl.vals[3])
