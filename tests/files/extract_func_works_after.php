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
}
