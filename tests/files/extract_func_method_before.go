package a

import "fmt"

type Foo struct {}

func (f *Foo) print() {
	fmt.Println("foo")
}
