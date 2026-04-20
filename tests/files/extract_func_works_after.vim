function! s:bar(b, c, d, e, f, g, h, k, j) abort
    let a = a + 1
    let a += a
    echo b
    echo c + 1
    echo d[0]
    echo e['e']
    echo f.f()
    echo g()
    if h
    endif
    while k
    endwhile
    let i = 'i'
    echo jreturn [a, i]
endfunction

function! s:foo(a) abort
    for j in range(0,5)
        let b = 'b'
        let c = 'c'
        let d = ['d']
        let e = {'e':'e'}
        let f = { }
        function f.f() abort
            return "f"
        endfunction
        let [g, h] = [{-> "g"}, "h"]
        let i
        let k = 'k'
        let l = 'l'

        let [a, i] = bar(b, c, d, e, f, g, h, k, j)

        echo a
        unlet b
        return i
    endfor
endfunction
