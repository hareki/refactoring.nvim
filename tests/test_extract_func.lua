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
---@param a integer
local function foo(a)
  for j = 1, 5 do
    local b = 'b'
    local c = 'c'
    local d = {'d'}
    local e = { e = 'e' }
    local f = {}
    function f.f(self) return 'f' end
    local g, h = function() return 'g' end, 'h'
    local i
    local k = 'k'
    local l = 'l'

    a = a + 1
    print(b)
    print(c + 1)
    print(d[1])
    print(e.e)
    print(f:f())
    print(g())
    if h then end
    while k do end
    repeat until l
    i = 'i'
    print(j)

    print(a)
    print(i)
  end
end
]]
  local expected_lines = [[
---@param b string
---@param c string
---@param d table
---@param e table
---@param f table
---@param g function
---@param h string
---@param k string
---@param l string
---@param i string
local function bar(a, b, c, d, e, f, g, h, k, l, i, j)
  a = a + 1
  print(b)
  print(c + 1)
  print(d[1])
  print(e.e)
  print(f:f())
  print(g())
  if h then end
  while k do end
  repeat until l
  i = 'i'
  print(j)

  return a, i
end

---@param a integer
local function foo(a)
  for j = 1, 5 do
    local b = 'b'
    local c = 'c'
    local d = {'d'}
    local e = { e = 'e' }
    local f = {}
    function f.f(self) return 'f' end
    local g, h = function() return 'g' end, 'h'
    local i
    local k = 'k'
    local l = 'l'

    local a, i = bar(a, b, c, d, e, f, g, h, k, l, i, j)

    print(a)
    print(i)
  end
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 15, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["java"] = MiniTest.new_set()

T["java"]["works"] = function()
  local lines = [[
class F {
    public String f() {
        return "f";
    }
}

record E (String e) {}

class Foo {
    public String foo(int a) {
        String i;
        for (int j = 0; j < 5; j++) {
            String b = "b";
            String c = "c";
            String[] d = {"d"};
            E e = new E("e");
            F f = new F();
            boolean g = true, h = false;
            boolean k = true;
            boolean l = true;

            a = a + 1;
            a += a;
            a++;
            ++a;
            System.out.println(b);
            System.out.println(c + 1);
            System.out.println(d[0]);
            System.out.println(e.e());
            System.out.println(f.f());
            System.out.println(g);
            if (h) {}
            while (k) {}
            do {} while (l);
            i = "i";
            System.out.println(j);

            return i;
        }
        return "";
    }
}
]]
  local expected_lines = [[
class F {
    public String f() {
        return "f";
    }
}

record E (String e) {}

class Foo {
    private String bar(int a, String b, String c, String[] d, E e, F f, boolean g, boolean h, boolean k, boolean l, String i, int j) {
        a = a + 1;
        a += a;
        a++;
        ++a;
        System.out.println(b);
        System.out.println(c + 1);
        System.out.println(d[0]);
        System.out.println(e.e());
        System.out.println(f.f());
        System.out.println(g);
        if (h) {}
        while (k) {}
        do {} while (l);
        i = "i";
        System.out.println(j);

        return i;
    }

    public String foo(int a) {
        String i;
        for (int j = 0; j < 5; j++) {
            String b = "b";
            String c = "c";
            String[] d = {"d"};
            E e = new E("e");
            F f = new F();
            boolean g = true, h = false;
            boolean k = true;
            boolean l = true;

            var i = bar(a, b, c, d, e, f, g, h, k, l, i, j);

            return i;
        }
        return "";
    }
}
]]
  child.cmd "edit tmp.java"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 22, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["php"] = MiniTest.new_set()

T["php"]["works"] = function()
  local lines = [[
<?php

class F {
    public function f(): string {
        return 'f';
    }
}

function foo(int $a) {
    for ($j = 0; $j < 5; $j++) {
        $b = 'b';
        $c = 'c';
        $d = ['d'];
        $e = [e => 'e'];
        $f = new F();
        [$g, $h] = [function($_g) { return 'g'; }, 'h'];
        $i = null;
        $k = 'k';
        $l = 'l';

        $a = $a + 1;
        $a += $a;
        $a++;
        ++$a;
        echo $b;
        echo $b, $b;
        print $b;
        print($b);
        print($c + 1);
        print($d[1]);
        print($e->e);
        print($f->f());
        print($g());
        $g($g);
        if ($h) {}
        while ($h) {}
        do {} while($h);
        $i = 'i';
        print($j);

        print($a);
        return $i;
    }
}]]
  local expected_lines = [[
<?php

class F {
    public function f(): string {
        return 'f';
    }
}

function bar(string $b, string $c, array $d, array $e, object $f, callable $g, string $h, int $j)
{
    $a = $a + 1;
    $a += $a;
    $a++;
    ++$a;
    echo $b;
    echo $b, $b;
    print $b;
    print($b);
    print($c + 1);
    print($d[1]);
    print($e->e);
    print($f->f());
    print($g());
    $g($g);
    if ($h) {}
    while ($h) {}
    do {} while($h);
    $i = 'i';
    print($j);

    return [$a, $i];
}

function foo(int $a) {
    for ($j = 0; $j < 5; $j++) {
        $b = 'b';
        $c = 'c';
        $d = ['d'];
        $e = [e => 'e'];
        $f = new F();
        [$g, $h] = [function($_g) { return 'g'; }, 'h'];
        $i = null;
        $k = 'k';
        $l = 'l';

        [$a, $i] = bar($b, $c, $d, $e, $f, $g, $h, $j);

        print($a);
        return $i;
    }
}]]
  child.cmd "edit tmp.php"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 21, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["go"] = MiniTest.new_set()

T["go"]["works"] = function()
  local lines = [[
package a

type F struct{}

func (f *F) f() string {
	return "f"
}

type E struct{ e string }

func foo(a int) string {
	for j := 0; j < 5; j++ {
		b := "b"
		c := 'c'
		d := [1]string{"d"}
		e := E{"e"}
		f := F{}
		g, h := func(_g string) string { print(_g); return "g" }, "h"
		var i string

		a = a + 1
		a += a
		a++
		print(b)
		print(c + 1)
		print(d[0])
		print(e.e)
		print(f.f())
		print(g("g"))
		g(g("g"))
		if h != "" {}
		for i !=""{}
		i = "i"
		print(j)

		print(a)
		return i
	}
	return ""
}]]
  local expected_lines = [[
package a

type F struct{}

func (f *F) f() string {
	return "f"
}

type E struct{ e string }

func bar(a int, b string, c rune, d [1]string, e E, f F, g func(), h string, i string, j int) (int, string) {
	a = a + 1
	a += a
	a++
	print(b)
	print(c + 1)
	print(d[0])
	print(e.e)
	print(f.f())
	print(g("g"))
	g(g("g"))
	if h != "" {}
	for i !=""{}
	i = "i"
	print(j)

	return a, i
}

func foo(a int) string {
	for j := 0; j < 5; j++ {
		b := "b"
		c := 'c'
		d := [1]string{"d"}
		e := E{"e"}
		f := F{}
		g, h := func(_g string) string { print(_g); return "g" }, "h"
		var i string

		a, i := bar(a, b, c, d, e, f, g, h, i, j)

		print(a)
		return i
	}
	return ""
}]]
  child.cmd "edit tmp.go"
  child.bo.expandtab = false
  validate(lines, { 21, 0 }, expected_lines, " aeip", "bar<cr>")
end
