function! Foo() abort
    let i = 3
    "__PRINT_VAR_START
    echom 'Foo i:' i|"__PRINT_VAR_END
    return i
endfunction
