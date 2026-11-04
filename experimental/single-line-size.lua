local axis=tex.dimen.mathaxis
local function radius(name)
 local b=tex.box[name]
 return math.max(b.height-axis,b.depth+axis)
end
local e=math.max(radius('leftcontent'),radius('rightcontent'))
local h=radius('fullcontent')
tex.sprint(string.format('\\par\\medskip\\noindent Measured: $E=%.2f$\\,pt, $H=%.2f$\\,pt.\\par',e/65536,h/65536))
for _,v in ipairs({
 {'1. Native maximum: $H$',h},
 {'2. Endpoints only: $E$',e},
 {'3. Geometric mean: $\\sqrt{EH}$',math.sqrt(e*h)},
 {'4. Arithmetic mean: $(E+H)/2$',(e+h)/2},
 {'5. Weighted mean: $0.25E+0.75H$',.25*e+.75*h},
}) do
 local r=math.floor(v[2]+.5)
 tex.sprint(string.format('\\Comparison{%s}{%d}{%.2f}',v[1],r,r/65536))
 texio.write_nl('term and log',string.format('BLEND %s radius=%.4fpt',v[1],r/65536))
end
