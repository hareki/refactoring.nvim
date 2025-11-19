(program) @scope.inside @scope @scope.outside

(method
  parameters: (_) @scope
  body: (_) @scope.inside @scope) @scope.outside

(class
  body: (body_statement) @scope.inside) @scope @scope.outside
