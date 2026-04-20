function! Foo() abort
    let i = 3
    "__PRINT_VAR_START
    echom '┆Foo┆ ╎i╎ ┊1┊:' i|"__PRINT_VAR_END
    return i
endfunction
