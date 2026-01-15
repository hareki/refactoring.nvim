local function foo2()
  local foo = "foo"

  return foo
end

local foo = foo2()

local function bar()
  print(foo)
end
