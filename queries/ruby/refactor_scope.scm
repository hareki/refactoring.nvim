(program) @scope.inside @scope

(method
  parameters: (_) @scope
  body: (_) @scope.inside @scope)

(class
  body: (body_statement) @scope.inside) @scope
