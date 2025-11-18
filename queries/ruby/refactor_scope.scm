(program) @scope

(method
  body: (_) @scope.inside) @scope

(class
  body: (body_statement) @scope.inside) @scope
