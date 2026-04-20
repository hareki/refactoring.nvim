function get-foo {
    $foo = 'foo'
    Write-Host $foo

    while ($true) {
        Write-Host $foo
        break
    }

    if ($true) {
        Write-Host $foo
    } else {
        Write-Host $foo
    }

    for ($i = 0; $i -lt 5; $i++) {
        Write-Host $foo
    }
}
