(do_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope @scope.outside

(while_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope @scope.outside

(catch_clause
  body: (statement_block
    .
    (_) @scope.inside)) @scope @scope.outside

(for_in_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope @scope.outside

(for_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope @scope.outside

(function_declaration
  parameters: (_) @scope
  body: (statement_block
    .
    (_) @scope.inside) @scope) @scope.outside

(class_declaration
  (class_body
    (method_definition
      parameters: (_) @scope
      body: (statement_block
        .
        (_) @scope.inside) @scope))) @scope.outside

(function_expression
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(program) @scope.inside @scope @scope.outside

(arrow_function
  body: (statement_block
    .
    (_) @scope.inside)) @scope @scope.outside

(if_statement
  consequence: (statement_block) @scope @scope.inside) @scope.outside

(if_statement
  alternative: (else_clause
    (statement_block) @scope @scope.inside)) @scope.outside

(class_declaration
  body: (class_body
    (_) @scope.inside)) @scope @scope.outside
