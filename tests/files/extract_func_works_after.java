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
