local out=assert(io.open('build/folded-profiles.jsonl','w'))
local function array(xs)
 local result={};for _,x in ipairs(xs) do result[#result+1]=string.format('%.17g',x) end
 return '['..table.concat(result,',')..']'
end
finaldelim_sizing.inspect_profile=function(t)
 if not t.folded then return end
 local terms={};for _,v in ipairs(t.terms) do terms[#terms+1]=array{v.x,v.finish,v.r,v.fold and 1 or 0} end
 out:write(string.format('{"case":"%s","width":%.17g,"lambda":%.17g,"q":%g,"radius":%.17g,"floor":%.17g,"positions":%s,"terms":[%s],"folds":%d}\n',
  finaldelim_sizing.test_case or '',t.width,t.lambda,t.q,t.radius,t.endpoint_radius,array(t.positions),table.concat(terms,','),t.fold_count))
 out:flush()
end
