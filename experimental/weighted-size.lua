-- Compatibility entry for historical research fixtures, not a user interface.
local M=require('finaldelim-size')
M.from_tex=false; M.enabled=false
M.configure{lambda_pt=20,q=8,scale=1,spanning_scope='endpoints'}
return M
