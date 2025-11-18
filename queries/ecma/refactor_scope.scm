(do_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(while_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(catch_clause
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(for_in_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(for_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(method_definition
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(function_declaration
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(function_expression
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(program) @scope

(arrow_function
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(if_statement
  consequence: (statement_block) @scope) @scope.outside

(if_statement
  alternative: (else_clause
    (statement_block) @scope)) @scope.outside

(class_declaration
  body: (class_body
    (_) @scope.inside)) @scope
