function! s:foo() abort
    let l:foo = "foo"
    echo l:foo
    while v:true
        echo l:foo
        break
    endwhile

    if v:true
        echo l:foo
    else
        echo l:foo
    endif

    for i in range(0, 5)
        echo l:foo
    endfor
endfunction
