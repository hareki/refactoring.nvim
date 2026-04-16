(function_definition
  body: (block) @scope.inside) @scope

(function_declaration
  parameters: (parameters) @scope
  body: (block) @scope @scope.inside)

(for_statement
  body: (block) @scope.inside) @scope

(repeat_statement
  body: (block) @scope.inside) @scope

(while_statement
  body: (block) @scope.inside) @scope

(do_statement
  body: (block) @scope.inside) @scope

(chunk) @scope @scope.inside

(if_statement
  consequence: (block) @scope @scope.inside)

(if_statement
  alternative: (else_statement
    body: (block) @scope @scope.inside))
