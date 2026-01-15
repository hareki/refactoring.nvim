class F
  def f
    return 'f'
  end
end

def bar(b, c, d, e, f, g, h, k, l, m, j):
  a = a
  a = a + 1
  a+=a
  a++
  print b
  print c + 1
  print d[0]
  print e['e']
  print f.f()
  print g.call()
  if h then end
  while k do end
  until l do end
  loop do break if m end
  [a,b].each do |v| puts "#{a} #{v}" end
  print(j)

  return a
end

def foo(a)
  for j in 1..5 do
    b = 'b'
    c = 'c'
    d = ['d', b]
    e = {'e' => 'e'}
    f = F.new
    g, h = ->() {"g"}, "h"
    k = 'k'
    l = 'l'
    m = 'm'

    a = bar(b, c, d, e, f, g, h, k, l, m, j)

    return a
  end
end
