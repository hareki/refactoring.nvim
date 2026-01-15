local b = function(x, y, z)
  print(x)
  y = y + z
  return x, y, z
end

b(1, 2, 3)
c, d, e = b()
