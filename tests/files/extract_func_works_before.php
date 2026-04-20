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
}
