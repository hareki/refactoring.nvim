---@module "mini.test"

local child = MiniTest.new_child_neovim()

local expect, eq = MiniTest.expect, MiniTest.expect.equality

---@type {[string]: any|{[string]: any}}
local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.restart { "-u", "scripts/minimal_init.lua" }
      child.bo.readonly = false
      -- NOTE: we use `vim.notify` to show warnings to users, this makes
      -- it easier to catch them with mini.test
      child.lua "vim.notify = function(msg) error(msg) end"
    end,
    post_once = child.stop,
  },
}

---@param lines string
local set_lines = function(lines)
  child.api.nvim_buf_set_lines(0, 0, -1, true, vim.split(lines, "\n"))
end

local get_lines = function()
  return child.api.nvim_buf_get_lines(0, 0, -1, true)
end

---@param row integer
---@param col integer
local set_cursor = function(row, col)
  child.api.nvim_win_set_cursor(0, { row, col })
end

---@param lines string
---@param cursor {[1]: integer, [2]: integer}
---@param expected_lines string
---@param ... string
local function validate(lines, cursor, expected_lines, ...)
  set_lines(lines)
  set_cursor(cursor[1], cursor[2])
  child.type_keys(...)
  eq(get_lines(), vim.split(expected_lines, "\n"))
end

T["lua"] = MiniTest.new_set()

T["lua"]["works"] = function()
  local lines = [[
local function bar()
  print("foo")
end
print("foo")

do
  print("foo")
end

while false do
  print("foo")
end

repeat
  print("foo")
until true

if true then
  print("foo")
else
  print("foo")
end

for i = 1, 2 do
  print("foo")
end
local baz = function()
  print("foo")
end
]]
  local expected_lines = [[
local foo = "foo"
local function bar()
  print(foo)
end
print(foo)

do
  print(foo)
end

while false do
  print(foo)
end

repeat
  print(foo)
until true

if true then
  print(foo)
else
  print(foo)
end

for i = 1, 2 do
  print(foo)
end
local baz = function()
  print(foo)
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 2, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["lua"]["works for 1 scope"] = function()
  local lines = [[
print("foo")
print("foo")
print("foo")
print("foo")
]]
  local expected_lines = [[
local foo = "foo"
print(foo)
print(foo)
print(foo)
print(foo)
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["lua"]["works for 1 nested scope"] = function()
  local lines = [[
local function bar()
  print("foo")
end
]]
  local expected_lines = [[
local function bar()
  local foo = "foo"
  print(foo)
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 2, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["lua"]["works for multiple scopes including global"] = function()
  local lines = [[
print("foo")

local function bar()
  print("foo")
end
]]
  local expected_lines = [[
local foo = "foo"
print(foo)

local function bar()
  print(foo)
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["javascript"] = MiniTest.new_set()

T["javascript"]["works"] = function()
  local lines = [[
function bar() {
  console.log("foo");
}

console.log("foo");

while (false) {
  console.log("foo");
}

do {
  console.log("foo");
} while (false);

if (true) {
  console.log("foo");
} else {
  console.log("foo");
}

for (let i = 0; i < 5; i++) {
  console.log("foo");
}
const baz = () => {
  console.log("foo");
};
]]
  local expected_lines = [[
const foo = "foo";
function bar() {
  console.log(foo);
}

console.log(foo);

while (false) {
  console.log(foo);
}

do {
  console.log(foo);
} while (false);

if (true) {
  console.log(foo);
} else {
  console.log(foo);
}

for (let i = 0; i < 5; i++) {
  console.log(foo);
}
const baz = () => {
  console.log(foo);
};
]]
  child.cmd "edit tmp.js"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 2, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["c"] = MiniTest.new_set()

T["c"]["works"] = function()
  local lines = [[
#include <stdio.h>
#include <stdbool.h>

int main() {
  printf("foo");

  while (false) {
    printf("foo");
  }

  do {
    printf("foo");
  } while (false);

  if (true) {
    int a;
    printf("foo");
  } else {
    printf("foo");
  }

  for (int i = 0; i < 5; i++) {
    printf("foo");
  }
}
]]
  local expected_lines = [[
#include <stdio.h>
#include <stdbool.h>

int main() {
  P foo = "foo";
  printf(foo);

  while (false) {
    printf(foo);
  }

  do {
    printf(foo);
  } while (false);

  if (true) {
    int a;
    printf(foo);
  } else {
    printf(foo);
  }

  for (int i = 0; i < 5; i++) {
    printf(foo);
  }
}
]]
  child.cmd "edit tmp.c"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 4, 11 }, expected_lines, " avi)", "foo<cr>")
end

T["c#"] = MiniTest.new_set()

T["c#"]["works"] = function()
  local lines = [[
class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("foo");

        while (false)
        {
            Console.WriteLine("foo");
        }

        do
        {
            Console.WriteLine("foo");
        } while (false);

        if (true)
        {
            Console.WriteLine("foo");
        }
        else
        {
            Console.WriteLine("foo");
        }

        for (int i = 0; i < 5; i++)
        {
            Console.WriteLine("foo");
        }
    }
}
]]
  local expected_lines = [[
class Program
{
    static void Main(string[] args)
    {
        var foo = "foo";
        Console.WriteLine(foo);

        while (false)
        {
            Console.WriteLine(foo);
        }

        do
        {
            Console.WriteLine(foo);
        } while (false);

        if (true)
        {
            Console.WriteLine(foo);
        }
        else
        {
            Console.WriteLine(foo);
        }

        for (int i = 0; i < 5; i++)
        {
            Console.WriteLine(foo);
        }
    }
}
]]
  child.cmd "edit tmp.cs"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 5, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["go"] = MiniTest.new_set()

T["go"]["works"] = function()
  local lines = [[
package a

import "fmt"

func main() {
	fmt.Println("foo")

	func() { fmt.Println("foo") }()

	for false {
		fmt.Println("foo")
	}

	if true {
		fmt.Println("foo")
	} else {
		fmt.Println("foo")
	}

	for i := 0; i < 5; i++ {
		fmt.Println("foo")
	}

        a := 1
	switch a {
	case 1:
		fmt.Println("foo")
	default:
		fmt.Println("foo")
	}
}
]]
  local expected_lines = [[
package a

import "fmt"

func main() {
	foo := "foo"
	fmt.Println(foo)

	func() { fmt.Println(foo) }()

	for false {
		fmt.Println(foo)
	}

	if true {
		fmt.Println(foo)
	} else {
		fmt.Println(foo)
	}

	for i := 0; i < 5; i++ {
		fmt.Println(foo)
	}

        a := 1
	switch a {
	case 1:
		fmt.Println(foo)
	default:
		fmt.Println(foo)
	}
}
]]
  child.cmd "edit tmp.go"
  child.bo.expandtab = false
  validate(lines, { 6, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["java"] = MiniTest.new_set()

T["java"]["works"] = function()
  local lines = [[
package org.example;

public class App {

    public static void main(String[] args) {

        System.out.println("foo");

        while (true) {
            System.out.println("foo");
            break;
        }

        do {
            System.out.println("foo");
        } while (false);

        if (true) {
            System.out.println("foo");
        } else {
            System.out.println("foo");
        }

        for (int i = 0; i < 5; i++) {
            System.out.println("foo");
        }

    }
}]]
  local expected_lines = [[
package org.example;

public class App {

    public static void main(String[] args) {

        var foo = "foo";
        System.out.println(foo);

        while (true) {
            System.out.println(foo);
            break;
        }

        do {
            System.out.println(foo);
        } while (false);

        if (true) {
            System.out.println(foo);
        } else {
            System.out.println(foo);
        }

        for (int i = 0; i < 5; i++) {
            System.out.println(foo);
        }

    }
}]]
  child.cmd "edit tmp.java"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 7, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["php"] = MiniTest.new_set()

T["php"]["works"] = function()
  local lines = [[
<?php

function foo()
{
    print ('foo');

    while (true) {
        print ('foo');
        break;
    }

    do {
        print ('foo');
    } while (false);

    if (true) {
        print ('foo');
    } else {
        print ('foo');
    }

    for ($i = 0; $i < 5; $i++) {
        print ('foo');
    }
}]]
  local expected_lines = [[
<?php

function foo()
{
    $foo = 'foo';
    print ($foo);

    while (true) {
        print ($foo);
        break;
    }

    do {
        print ($foo);
    } while (false);

    if (true) {
        print ($foo);
    } else {
        print ($foo);
    }

    for ($i = 0; $i < 5; $i++) {
        print ($foo);
    }
}]]
  child.cmd "edit tmp.php"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 5, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["python"] = MiniTest.new_set()

T["python"]["works"] = function()
  local lines = [[
def foo():
    print("foo")

    while True:
        print("foo")
        break

    if True:
        print("foo")
    else:
        print("foo")

    for i in range(0, 5):
        print("foo")]]
  local expected_lines = [[
def foo():
    foo = "foo"
    print(foo)

    while True:
        print(foo)
        break

    if True:
        print(foo)
    else:
        print(foo)

    for i in range(0, 5):
        print(foo)]]
  child.cmd "edit tmp.py"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 2, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["ruby"] = MiniTest.new_set()

T["ruby"]["works"] = function()
  local lines = [[
def foo()
    print "foo"

    while true do
        print "foo"
        break
    end

    if true then
        print "foo"
    else
        print "foo"
    end

    for i in range(0, 5) do
        print "foo"
    end

    [:a, :b].each do |item|
        print "foo"
    end

    [:a, :b].each {|item|
        print "foo"
    }
end]]
  local expected_lines = [[
def foo()
    foo = "foo"
    print foo

    while true do
        print foo
        break
    end

    if true then
        print foo
    else
        print foo
    end

    for i in range(0, 5) do
        print foo
    end

    [:a, :b].each do |item|
        print foo
    end

    [:a, :b].each {|item|
        print foo
    }
end]]
  child.cmd "edit tmp.rb"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 2, 0 }, expected_lines, 'f"', ' avf"', "foo<cr>")
end

return T
