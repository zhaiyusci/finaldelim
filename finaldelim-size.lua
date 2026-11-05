-- Experimental measure -> single-line layout -> physical partition pipeline.
-- The input is an already parsed math list; user source is never replayed.
local M = { enabled = true, measured = 0 }
M.spanning_scope='folded'
M.from_tex=true
M.config={lambda_pt=20,q=8,scale=0.9,fold_width_pt=0.1}
function M.configure(options)
 for k,v in pairs(options) do
  if k=='spanning_scope' then assert(v=='endpoints' or v=='full' or v=='folded','Invalid spanning_scope')
  else
   assert(M.config[k]~=nil and type(v)=='number' and v==v and v<math.huge)
   assert((k=='q' and v>=0) or (k~='q' and v>0))
  end
 end
 for k,v in pairs(options) do
  if k=='spanning_scope' then M.spanning_scope=v else M.config[k]=v end
 end
end
M.configure(M.config)
local fence, noad, sub = node.id('fence'), node.id('noad'), node.id('sub_mlist')
local hl, vl = node.id('hlist'), node.id('vlist')
local function marker(n)
 return n.id == node.id('whatsit') and n.subtype == node.subtype('user_defined') and n.user_id == 0x4D53
end
local function hascut(head)
 for n in node.traverse(head) do
  if marker(n) then return true end
  if (n.id == hl or n.id == vl) and hascut(n.list) then return true end
 end
 return false
end
-- Temporary fence-position markers exist only in copied measurements or during
-- one native conversion; none reach the output PDF.
local fence_marker_id = 0x4644
local function fence_marker(n)
 return n.id == node.id('whatsit') and n.subtype == node.subtype('user_defined')
  and n.user_id == fence_marker_id
end
local function profile(box,style,all_fences,folded)
 local axis=tex.getmath('axis',style)
 local terms,positions={},{}; local L,H=math.huge,0
 local row,starts,position_rows=1,{0},{}
 local rowext={{h=0,d=0}}
 local function scan(head,x,shift,parent)
  for n in node.traverse(head) do
   local width=n.width or 0
   if n.id==node.id('glue') then width=node.effective_glue(n,parent)
   elseif n.id==node.id('kern') then width=n.kern end
   if marker(n) and n.value==2 then
    row=row+1;starts[row]=x;rowext[row]={h=0,d=0}
   end
   if fence_marker(n) and n.value>0 then
    positions[#positions+1]=x;position_rows[#positions]=row
   end
   if n.id==hl and hascut(n.list) then
    scan(n.list,x,shift+n.shift,n)
   elseif n.id==hl or n.id==vl or n.id==node.id('glyph') or n.id==node.id('rule') then
    local sh=shift+((n.id==hl or n.id==vl) and n.shift or 0)
    rowext[row].h=math.max(rowext[row].h,n.height-sh)
    rowext[row].d=math.max(rowext[row].d,n.depth+sh)
    if width>0 then
     local r=math.max(n.height-sh-axis,n.depth+sh+axis,0)
     terms[#terms+1]={x=x,finish=x+width,r=r,row=row}
     L=math.min(L,r); H=math.max(H,r)
    end
   end
   x=x+width
  end
 end
 scan(box.list,0,0,box)
 if #terms==0 or H==0 then return box.height,box.depth end
 local W=box.width
 local endpoint_radius,fold_count=0,0
 if folded and row>1 then
  starts[row+1]=W
  local keep={[1]=true,[row]=true}
  for _,r in ipairs(position_rows) do keep[r]=true end
  local mapped,newterms,newW={}, {},0
  local current=1
  while current<=row do
   if keep[current] then
    mapped[current]=newW-starts[current]
    endpoint_radius=math.max(endpoint_radius,rowext[current].h-axis,rowext[current].d+axis)
    for _,v in ipairs(terms) do
     if v.row==current then
      newterms[#newterms+1]={x=v.x+mapped[current],finish=v.finish+mapped[current],r=v.r}
     end
    end
    newW=newW+starts[current+1]-starts[current]
    current=current+1
   else
    local radius=0
    repeat
     radius=math.max(radius,rowext[current].h-axis,rowext[current].d+axis)
     current=current+1
    until current>row or keep[current]
    -- Keep the synthetic width on TeX's integer scaled-point grid.
    local width=math.max(1,math.floor(M.config.fold_width_pt*65536+0.5))
    newterms[#newterms+1]={x=newW,finish=newW+width,r=radius,fold=true}
    newW=newW+width;fold_count=fold_count+1
   end
  end
  for i,x in ipairs(positions) do positions[i]=x+mapped[position_rows[i]] end
  terms,W=newterms,newW
  L,H=math.huge,0
  for _,v in ipairs(terms) do L=math.min(L,v.r);H=math.max(H,v.r) end
  H=math.max(H,endpoint_radius)
 end
 local lambda=M.config.lambda_pt*65536
 local q=M.config.q
 local R=H
 if q>0 then
  local last=0
  for _,v in ipairs(terms) do
   if v.x<last-1 or v.x<0 or v.finish>W+1 then return box.height,box.depth end
   last=v.finish
  end
  if not all_fences then positions={0,W} end
  -- Integral divided by lambda; the scale cancels in each normalized mean.
  local function weight(a,b,at)
   if b<=at then return math.exp(-(at-b)/lambda)-math.exp(-(at-a)/lambda) end
   if a>=at then return math.exp(-(a-at)/lambda)-math.exp(-(b-at)/lambda) end
   return 2-math.exp(-(at-a)/lambda)-math.exp(-(b-at)/lambda)
  end
  local floor=(L/H)^q
  local maximum=0
  for _,at in ipairs(positions) do
   local norm=weight(0,W,at)
   local value=floor*norm
   for _,v in ipairs(terms) do
    value=value+((v.r/H)^q-floor)*weight(v.x,v.finish,at)
   end
   maximum=math.max(maximum,math.max(0,value/norm)^(1/q))
  end
  R=H*maximum
 end
 if folded then R=math.max(R,endpoint_radius) end
 if M.inspect_profile then
  M.inspect_profile{terms=terms,positions=all_fences and positions or {0,W},
   width=W,lambda=lambda,q=q,scale=M.config.scale,radius=R,axis=axis,
   folded=folded or false,fold_count=fold_count,endpoint_radius=endpoint_radius}
 end
 assert(R>=L-1 and R<=H+1)
 return math.floor(R+axis+.5),math.floor(R-axis+.5)
end
local function dimensions(box)
 local cells, index, rows = {{h=0,d=0}}, 1, 0
 local rowdims={{h=0,d=0}}
 local fence_rows={}
 local function scan(list, shift)
  for n in node.traverse(list) do
   if fence_marker(n) and n.value>0 then fence_rows[rows+1]=true end
   if marker(n) then
    if n.value == 2 then rows = rows + 1; rowdims[rows+1]={h=0,d=0} end
    index = index + 1; cells[index] = {h=0,d=0}
   elseif (n.id == hl or n.id == vl) and hascut(n.list) then
    assert(n.id == hl, 'Endpoint prototype requires horizontal cuts')
    scan(n.list, shift + n.shift)
   elseif n.id == hl or n.id == vl or n.id == node.id('glyph') or n.id == node.id('rule') then
    local s = shift + ((n.id == hl or n.id == vl) and n.shift or 0)
    cells[index].h = math.max(cells[index].h, n.height - s)
    cells[index].d = math.max(cells[index].d, n.depth + s)
    rowdims[rows+1].h=math.max(rowdims[rows+1].h,n.height-s)
    rowdims[rows+1].d=math.max(rowdims[rows+1].d,n.depth+s)
   end
  end
 end
 scan(box.list, 0)
 return cells[1], cells[index], rows, rowdims[1], rowdims[#rowdims], rowdims, fence_rows
end
local function measure(head, stop, style)
 -- Physics and other macros may add an ordinary group around their entire
 -- argument. Look through that wrapper for measurement, never for layout.
 while head and head.next==stop and head.id==noad and head.subtype==0
  and not head.sup and not head.sub and head.nucleus and head.nucleus.id==sub do
  head,stop=head.nucleus.head,nil
 end
 local copy = node.copy_list(head, stop)
 local box = node.hpack(node.mlist_to_hlist(copy, style, false))
 local a,b,rows,firstrow,lastrow = dimensions(box)
 local h,d
 if rows>0 and M.spanning_scope=='endpoints' then
  -- Spanning pairs retain the endpoint policy; middle rows do not size fences.
  h,d=math.max(firstrow.h,lastrow.h),math.max(firstrow.d,lastrow.d)
 else h,d=profile(box,style,false,rows>0 and M.spanning_scope=='folded') end
 node.flush_node(box)
 return a,b,rows,h,d
end
local function scaled_extent(h,d,style)
 local axis=tex.getmath('axis',style)
 local radius=math.max(h-axis,d+axis,0)*M.config.scale
 return math.floor(axis+radius+.5),math.floor(radius-axis+.5)
end
local function delimiters(first,last,h,d,style)
 -- Let native left/right select AND position both delimiters around the axis.
 local l,r = node.copy(first),node.copy(last)
 l.next,l.prev,r.next,r.prev = nil,nil,nil,nil
 l.height,l.depth,r.height,r.depth = 0,0,0,0
 local rule = node.new('rule'); rule.width,rule.height,rule.depth = 0,h,d
 l.next,rule.prev,rule.next,r.prev = rule,l,r,rule
 local result = node.mlist_to_hlist(l,style,false)
 local tail = node.tail(result)
 assert((result.id==hl or result.id==vl) and (tail.id==hl or tail.id==vl),'Expected native delimiter boxes')
 local middle = result.next
 result.next,middle.prev,tail.prev.next,tail.prev = nil,nil,nil,nil
 node.flush_list(middle)
 if M.render_delimiter then
  result=M.render_delimiter(result,first,h,d,style)
  tail=M.render_delimiter(tail,last,h,d,style)
 end
 return result,tail
end
local function boxed_noad(box, subtype, attr)
 local n = node.new('noad',subtype)
 n.attr = attr
 n.nucleus = node.new('sub_box'); n.nucleus.head = box
 return n
end
local function attachment(box,last)
 if last.delim.small_char==0 and last.delim.large_char==0 then return end
 return {h=box.height-box.shift,d=box.depth+box.shift}
end
local function attach_scripts(box,owner,style,anchor)
 if not anchor or (not owner.sup and not owner.sub) then return box end
 -- TeX lays out scripts against a zero-width nucleus with the final right
 -- fence's extent. Actual content keeps its own dimensions and color resets.
 local base=node.new('hlist');base.height,base.depth=anchor.h,anchor.d
 local n=boxed_noad(base,0,owner.attr)
 n.sup,n.sub=owner.sup,owner.sub
 owner.sup,owner.sub=nil,nil
 local scripts=node.mlist_to_hlist(n,style,false)
 local tail=node.tail(box.list);tail.next,scripts.prev=scripts,tail
 local result=node.hpack(box.list);box.list=nil;node.free(box)
 local _,ending,rows=dimensions(result)
 if rows>0 then result.height,result.depth=ending.h,ending.d end
 return result
end
-- Use real fence noads throughout conversion: in particular, middle's native
-- spacing/class behaviour must not be approximated by an ordinary/relation atom.
local function new_fence_marker(value)
 local n=node.new('whatsit','user_defined')
 n.user_id,n.type,n.value=fence_marker_id,100,value
 return n
end
local function wrap_fences(head,blank)
 local n,index=head,0
 while n do
  local nextnode=n.next
  if n.id==fence then
   index=index+1
   if blank then
    n.delim.small_char,n.delim.large_char=0,0
    n.delim.small_fam,n.delim.large_fam=0,0
   end
   head=node.insert_before(head,n,new_fence_marker(index))
   head=node.insert_after(head,n,new_fence_marker(-index))
  end
  n=nextnode
 end
 return head,index
end
local function fence_boxes(head,replacements,measurement)
 local active,found=nil,{}
 local n=head
 while n do
  local nextnode=n.next
  if fence_marker(n) then
   active=n.value>0 and n.value or nil
   if not measurement then
    head=node.remove(head,n);node.free(n)
   end
  elseif active and (n.id==hl or n.id==vl) then
   assert(not found[active],'Multiple boxes for a native fence')
   found[active]=n
   if measurement then
    n.width,n.height,n.depth,n.shift=0,0,0,0
   elseif replacements then
    local replacement=assert(replacements[active],'Missing native fence box')
    head=node.insert_before(head,n,replacement)
    head=node.remove(head,n);node.flush_node(n)
   else
    head=node.remove(head,n)
    n.next,n.prev=nil,nil
   end
  end
  n=nextnode
 end
 return head,found
end
local function process_middles(head,style)
 -- Measure content without allowing the provisional fence glyphs to size
 -- themselves. Zero-width fence boxes retain native spacing between atoms.
 local copy,count=wrap_fences(node.copy_list(head),true)
 local measured=node.mlist_to_hlist(copy,style,false)
 measured=fence_boxes(measured,nil,true)
 local box=node.hpack(measured)
 local _,_,rows,_,_,rowdims,fence_rows=dimensions(box)
 local h,d=0,0
 if rows>0 and M.spanning_scope=='endpoints' then
  -- Generalize endpoint rows to every row on which a delimiter appears.
  for row in pairs(fence_rows) do
   h=math.max(h,rowdims[row].h);d=math.max(d,rowdims[row].d)
  end
 else h,d=profile(box,style,true,rows>0 and M.spanning_scope=='folded') end
 node.flush_node(box)
 h,d=scaled_extent(h,d,style)
 -- Ask native TeX to build all fence glyphs around the selected extent.
 local probe,tail
 for n in node.traverse(head) do
  if n.id==fence then
   local f=node.copy(n);f.next,f.prev=nil,tail
   if tail then tail.next=f else probe=f end
   tail=f
  end
 end
 local rule=node.new('rule');rule.width,rule.height,rule.depth=0,h,d
 probe=node.insert_after(probe,probe,rule)
 probe=wrap_fences(probe,false)
 local rest,delimiters=fence_boxes(node.mlist_to_hlist(probe,style,false))
 node.flush_list(rest)
 assert(#delimiters==count,'Native fence count changed')
 if M.render_delimiter then
  local index=0
  for n in node.traverse(head) do
   if n.id==fence then index=index+1;delimiters[index]=M.render_delimiter(delimiters[index],n,h,d,style) end
  end
 end
 local anchor=attachment(delimiters[count],node.tail(head))
 -- Convert the actual contents once, preserving native math spacing, then
 -- substitute only the already selected fence boxes before packing the row.
 head=wrap_fences(head,false)
 local actual=node.mlist_to_hlist(head,style,false)
 actual=fence_boxes(actual,delimiters,false)
 local result=node.hpack(actual)
 local _,ending=dimensions(result)
 if rows>0 then result.height,result.depth=ending.h,ending.d end
 M.measured=M.measured+1
 texio.write_nl('log',string.format('WEIGHTED middles %d: fences=%d %.3fpt / %.3fpt',
  M.measured,count,h/65536,d/65536))
 return result,anchor
end
local process
local function children(head,style)
 local only,anchor=0,nil
 for n in node.traverse(head) do
  if n.id == node.id("style") then style = n.style end
  if n.id~=node.id('whatsit') and n.id~=node.id('style') then only=only+1 end
  if n.id == noad and n.nucleus and n.nucleus.id == sub then
   local b,a = process(n.nucleus.head,style)
   local scripted=n.sup or n.sub
   if b then
    n.nucleus.head = nil; node.free(n.nucleus)
    n.nucleus = node.new('sub_box'); n.nucleus.head = attach_scripts(b,n,style,a)
    if not scripted then anchor=a end
   end
  end
 end
 -- Transparent grouping/color wrappers preserve the closing-fence anchor.
 if only==1 then return anchor end
end
process = function(head,style)
 local anchor=children(head,style)
 node.slide(head)
 local first,last = head,node.tail(head)
 if not first then return end
 local paired = first.id == fence and last.id == fence and first ~= last
 if paired and first.next==last then return end
 if paired then
  -- Explicit sizes remain on the native path.
  if first.height~=0 or first.depth~=0 or last.height~=0 or last.depth~=0 then return end
  local hasmiddle=false
  for n in node.traverse(first.next) do
   if n~=last and n.id==fence then
    if n.subtype~=2 or n.height~=0 or n.depth~=0 then return end
    hasmiddle=true
   end
  end
  if hasmiddle then return process_middles(head,style) end
 end
 local a,b,rows,h,d = measure(paired and first.next or head, paired and last or nil,style)
 if rows == 0 and not paired and not anchor then return end
 if paired then
  h,d=scaled_extent(h,d,style)
  local lbox,rbox = delimiters(first,last,h,d,style)
  anchor=attachment(rbox,last)
  local l,r = boxed_noad(lbox,6,first.attr),boxed_noad(rbox,7,last.attr)
  local inner,ending = first.next,last.prev
  l.next,inner.prev,ending.next,r.prev = inner,l,r,ending
  first.next,first.prev,last.next,last.prev = nil,nil,nil,nil
  node.flush_node(first); node.flush_node(last)
  head = l
  M.measured = M.measured + 1
  texio.write_nl('log',string.format('WEIGHTED pair %d: %.3fpt / %.3fpt',M.measured,h/65536,d/65536))
 end
 -- Final continuous layout. Preserve every actual child box and its dimensions.
 local box = node.hpack(node.mlist_to_hlist(head,style,false))
 local _,ending = dimensions(box)
 -- Only the enclosing math atom's attachment metrics use its endpoint cell.
 -- The physical partitioner later repacks actual children into real row boxes.
 if rows>0 then box.height,box.depth = ending.h,ending.d end
 return box,anchor
end
luatexbase.add_to_callback('pre_mlist_to_hlist_filter',function(head,style)
 local active=M.enabled
 if M.from_tex then
  active=tex.count['l__fd_sizing_int']==1
  if active then
   M.configure{lambda_pt=tex.dimen['l__fd_lambda_dim']/65536,
    fold_width_pt=tex.dimen['l__fd_fold_width_dim']/65536,
    q=tonumber(token.get_macro('fdSizingQ')),scale=tonumber(token.get_macro('fdSizingScale')),
    spanning_scope=token.get_macro('l__fd_span_tl')}
  end
 end
 if active then children(head,style) end
 return head
end,'finaldelim.sizing')
return M
