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
