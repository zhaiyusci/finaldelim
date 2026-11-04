local out=assert(io.open('build/middle-profiles.jsonl','w'))
local function array(xs)
 local result={}
 for _,x in ipairs(xs) do result[#result+1]=string.format('%.17g',x) end
 return '['..table.concat(result,',')..']'
end
finaldelim_sizing.inspect_profile=function(t)
 local terms={}
 for _,v in ipairs(t.terms) do terms[#terms+1]=array{v.x,v.finish,v.r} end
 out:write(string.format('{"case":"%s","width":%.17g,"lambda":%.17g,"q":%g,"scale":%g,"radius":%.17g,"positions":%s,"terms":[%s]}\n',
  finaldelim_sizing.test_case or '',t.width,t.lambda,t.q,t.scale,t.radius,array(t.positions),table.concat(terms,',')))
 out:flush()
end
