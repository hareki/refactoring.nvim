local bar = "bar"
local foo = "foo"
-- __PRINT_VAR_START
print([==[foo:]==], vim.inspect(foo))
print([==[bar:]==], vim.inspect(bar))-- __PRINT_VAR_END
print(foo)
print(foo)
print(foo)
print(foo)
print(bar)
print(bar)
