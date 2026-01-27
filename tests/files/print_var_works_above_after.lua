local bar = "bar"
local foo = "foo"
-- __PRINT_VAR_START
print([==[┆┆ ╎foo╎ ┊1┊:]==], vim.inspect(foo))
print([==[┆┆ ╎bar╎ ┊1┊:]==], vim.inspect(bar))-- __PRINT_VAR_END
print(foo)
print(foo)
print(foo)
print(foo)
print(bar)
print(bar)
