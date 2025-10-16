---@module "mini.test"
-- TODO: add tests for extract_func_to_file

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

T["lua"]["defaults to extracted location"] = function()
  local lines = [[
local foo = "foo"
print(foo)
]]
  local expected_lines = [[
local function bar()
  local foo = "foo"
  print(foo)
end

bar()
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["lua"]["identifies references outside extracted range scope"] = function()
  local lines = [[
local foo = "foo"

local function bar()
  print(foo)
end
]]
  local expected_lines = [[
local function foo2()
  local foo = "foo"

  return foo
end

local foo = foo2()

local function bar()
  print(foo)
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " ae_", "foo2<cr>")
end

T["lua"]["chooses correct declaration"] = function()
  local lines = [[
local foo = "foo"

local function bar()
  local foo = "foo"
  print(foo)
end
]]
  local expected_lines = [[
local function foo2()
  local foo = "foo"
end

foo2()

local function bar()
  local foo = "foo"
  print(foo)
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " ae_", "foo2<cr>")
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

T["powershell"] = MiniTest.new_set()

T["powershell"]["works"] = function()
  local lines = [[
class _F {
    [string]f() {
        return 'f'
    }
}

function Get-Foo {
    param([int]$a)

    for ($j = 0; $j -lt 5; $j++) {
        $b = 'b'
        $c = 'c'
        $d = @('d')
        $e = @{e = 'e'}
        $f = [_F]::new()
        $g, $h = {return 'g'}, 'h'
        $i
        $k = 'k'
        $l = 'l'

        $a = $a + 1
        $a += $a
        $a++
        $a--
        ++$a
        --$a
        Write-Host $b
        $c + 1
        Write-Host $d[0]
        Write-Host $e.e
        Write-Host $f.f()
        Write-Host $g.Invoke()
        $g.Invoke($g)
        if ($h) { 
        }
        while ($k) {
        }
        do {
        } while ($l)
        $i = 'i'
        Write-Host $j

        Write-Host $a
        return $i
    }   
}]]
  local expected_lines = [[
class _F {
    [string]f() {
        return 'f'
    }
}

function bar
{
param ($b,
$c,
$d,
$e,
$f,
$g,
$h,
$k,
$l,
$j)
    $a = $a + 1
    $a += $a
    $a++
    $a--
    ++$a
    --$a
    Write-Host $b
    $c + 1
    Write-Host $d[0]
    Write-Host $e.e
    Write-Host $f.f()
    Write-Host $g.Invoke()
    $g.Invoke($g)
    if ($h) { 
    }
    while ($k) {
    }
    do {
    } while ($l)
    $i = 'i'
    Write-Host $j

    return @($a, $i)
}

function Get-Foo {
    param([int]$a)

    for ($j = 0; $j -lt 5; $j++) {
        $b = 'b'
        $c = 'c'
        $d = @('d')
        $e = @{e = 'e'}
        $f = [_F]::new()
        $g, $h = {return 'g'}, 'h'
        $i
        $k = 'k'
        $l = 'l'

        $out = bar $b $c $d $e $f $g $h $k $l $j

        Write-Host $a
        return $i
    }   
}]]
  child.cmd "edit tmp.ps1"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 21, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["python"] = MiniTest.new_set()

T["python"]["works"] = function()
  local lines = [[
class F:
    e = "e"

    def f(self):
        return "f"


def foo(a: int, l):
    for j in range(0, 5):
        b = "b"
        c = "c"
        d = ["d"]
        e = {"e": "e"}
        f = F()
        (g, h) = (lambda _g: "g", "h")
        k = "k"

        a = a + 1
        a = a
        a += a
        print(b)
        print(c + "1", sep=c)
        print(d[0])
        print(e["e"])
        print(f.e)
        print(f.f())
        print(g(None))
        g(g)
        if h:
            pass
        while k:
            pass
        for item in l:
          pass
        print(j)
        print(l)

        print(a)
        return j]]
  local expected_lines = [[
class F:
    e = "e"

    def f(self):
        return "f"


def bar(b, c, d, e, f, g, h, k, l, j):
    a = a + 1
    a = a
    a += a
    print(b)
    print(c + "1", sep=c)
    print(d[0])
    print(e["e"])
    print(f.e)
    print(f.f())
    print(g(None))
    g(g)
    if h:
        pass
    while k:
        pass
    for item in l:
      pass
    print(j)
    print(l)

    return a

def foo(a: int, l):
    for j in range(0, 5):
        b = "b"
        c = "c"
        d = ["d"]
        e = {"e": "e"}
        f = F()
        (g, h) = (lambda _g: "g", "h")
        k = "k"

        a = bar(b, c, d, e, f, g, h, k, l, j)

        print(a)
        return j]]
  child.cmd "edit tmp.py"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 18, 8 }, expected_lines, " aeip", "bar<cr>")
end

T["ruby"] = MiniTest.new_set()

T["ruby"]["works"] = function()
  local lines = [[
class F
  def f
    return 'f'
  end
end

def foo(a)
  for j in 1..5 do
    b = 'b'
    c = 'c'
    d = ['d', b]
    e = {'e' => 'e'}
    f = F.new
    g, h = ->() {"g"}, "h"
    k = 'k'
    l = 'l'
    m = 'm'

    a = a
    a = a + 1
    a+=a
    a++
    print b
    print c + 1
    print d[0]
    print e['e']
    print f.f()
    print g.call()
    if h then end
    while k do end
    until l do end
    loop do break if m end
    [a,b].each do |v| puts "#{a} #{v}" end
    print(j)

    return a
  end
end
]]
  local expected_lines = [[
class F
  def f
    return 'f'
  end
end

def bar(b, c, d, e, f, g, h, k, l, m, j):
  a = a
  a = a + 1
  a+=a
  a++
  print b
  print c + 1
  print d[0]
  print e['e']
  print f.f()
  print g.call()
  if h then end
  while k do end
  until l do end
  loop do break if m end
  [a,b].each do |v| puts "#{a} #{v}" end
  print(j)

  return a
end

def foo(a)
  for j in 1..5 do
    b = 'b'
    c = 'c'
    d = ['d', b]
    e = {'e' => 'e'}
    f = F.new
    g, h = ->() {"g"}, "h"
    k = 'k'
    l = 'l'
    m = 'm'

    a = bar(b, c, d, e, f, g, h, k, l, m, j)

    return a
  end
end
]]
  child.cmd "edit tmp.rb"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 19, 4 }, expected_lines, " aeip", "bar<cr>")
end

T["vimscript"] = MiniTest.new_set()

T["vimscript"]["works"] = function()
  local lines = [[
function! s:foo(a) abort
    for j in range(0,5)
        let b = 'b'
        let c = 'c'
        let d = ['d']
        let e = {'e':'e'}
        let f = { }
        function f.f() abort
            return "f"
        endfunction
        let [g, h] = [{-> "g"}, "h"]
        let i
        let k = 'k'
        let l = 'l'

        let a = a + 1
        let a += a
        echo b
        echo c + 1
        echo d[0]
        echo e['e']
        echo f.f()
        echo g()
        if h
        endif
        while k
        endwhile
        let i = 'i'
        echo j

        echo a
        unlet b
        return i
    endfor
endfunction
]]
  local expected_lines = [[
function! s:bar(b, c, d, e, f, g, h, k, j) abort
    let a = a + 1
    let a += a
    echo b
    echo c + 1
    echo d[0]
    echo e['e']
    echo f.f()
    echo g()
    if h
    endif
    while k
    endwhile
    let i = 'i'
    echo jreturn [a, i]
endfunction

function! s:foo(a) abort
    for j in range(0,5)
        let b = 'b'
        let c = 'c'
        let d = ['d']
        let e = {'e':'e'}
        let f = { }
        function f.f() abort
            return "f"
        endfunction
        let [g, h] = [{-> "g"}, "h"]
        let i
        let k = 'k'
        let l = 'l'

        let [a, i] = bar(b, c, d, e, f, g, h, k, j)

        echo a
        unlet b
        return i
    endfor
endfunction
]]
  child.cmd "edit tmp.vim"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 16, 8 }, expected_lines, " aeip", "bar<cr>")
end

return T
