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
}
