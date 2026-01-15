function get-foo {
    $i = 3
    # __PRINT_VAR_START
    Write-Host 'get-foo $i:' $i # __PRINT_VAR_END
    return $i
}
