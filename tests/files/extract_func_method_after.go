package a

import "fmt"

type Foo struct {}

func (f *Foo) foo() {
	fmt.Println("foo")
}

func (f *Foo) print() {
	f.foo()
}
