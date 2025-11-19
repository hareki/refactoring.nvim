(source_file) @scope.inside @scope @scope.outside

(func_literal
  body: (block
    (_) @scope.inside)) @scope @scope.outside

(function_declaration
  parameters: (parameter_list) @scope
  body: (block
    (statement_list) @scope.inside) @scope) @scope.outside

(method_declaration
  parameters: (parameter_list) @scope
  body: (block
    (_) @scope.inside) @scope) @scope.outside

(if_statement
  initializer: (_)? @scope
  condition: (_) @scope
  consequence: (block
    (statement_list) @scope.inside @scope)) @scope.outside

(if_statement
  initializer: (_)? @scope
  condition: (_) @scope
  alternative: (block
    (statement_list) @scope.inside @scope)) @scope.outside

(expression_switch_statement
  initializer: (_)? @scope
  value: (_) @scope
  (expression_case
    (statement_list) @scope.inside) @scope) @scope.outside

(expression_switch_statement
  initializer: (_)? @scope
  value: (_) @scope
  (default_case
    (statement_list) @scope.inside) @scope) @scope.outside

(for_statement
  body: (block
    (_) @scope.inside)) @scope @scope.outside
