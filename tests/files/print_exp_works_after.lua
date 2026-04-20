local function is_true()
  return true
end

-- __PRINT_EXP_START
print([==[┆┆ ╎is_true()╎ ┊1┊:]==], vim.inspect(is_true()))-- __PRINT_EXP_END
if is_true() then
  print('foo')
end
