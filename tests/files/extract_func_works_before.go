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
}
