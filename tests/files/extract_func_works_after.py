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
        return j
