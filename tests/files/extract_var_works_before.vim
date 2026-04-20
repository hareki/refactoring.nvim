function! s:foo() abort
    echo "foo"
    while v:true
        echo "foo"
        break
    endwhile

    if v:true
        echo "foo"
    else
        echo "foo"
    endif

    for i in range(0, 5)
        echo "foo"
    endfor
endfunction
