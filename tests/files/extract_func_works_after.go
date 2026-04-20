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
}
