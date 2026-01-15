def foo()
    foo = "foo"
    print foo

    while true do
        print foo
        break
    end

    if true then
        print foo
    else
        print foo
    end

    for i in range(0, 5) do
        print foo
    end

    [:a, :b].each do |item|
        print foo
    end

    [:a, :b].each {|item|
        print foo
    }
end
