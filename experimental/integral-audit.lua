local out=assert(io.open('build/integral-audit.txt','a'))
local used={}
local function scan(head)
 for n in node.traverse(head) do
  if n.id==node.id('glyph') then used[n.font]=used[n.font] or {};used[n.font][n.char]=(used[n.font][n.char] or 0)+1
  elseif n.list then scan(n.list) end
 end
end
scan(radical_audit_box.list)
out:write(radical_test_font..'\n')
for _,code in ipairs{0x222B,0x222C,0x222D,0x222E} do
 local variants,assembly,actual=0,false,0
 for id,chars in pairs(used) do
  local f=font.getfont(id);local char=code;local seen={};local count=0
  while char and not seen[char] do
   seen[char]=true;local ch=f.characters[char];if not ch then break end
   count=count+1;assembly=assembly or ch.vert_variants~=nil
   actual=actual+(chars[char] or 0);char=ch.next
  end
  variants=math.max(variants,count)
 end
 out:write(string.format('U+%04X variants=%d assembly=%s actual-glyphs=%d\n',code,variants,tostring(assembly),actual))
end
out:close()
