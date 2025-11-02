(func_literal
  body: (block
    (_) @scope.inside)) @scope

(source_file) @scope

(function_declaration
  body: (block
    (statement_list) @scope.inside)) @scope

(if_statement) @scope

(if_statement
  consequence: (block
    (statement_list) @scope)) @scope.outside

(if_statement
  alternative: (block
    (statement_list) @scope)) @scope.outside

(expression_switch_statement) @scope

(expression_case
  (statement_list) @scope.inside) @scope

(default_case
  (statement_list) @scope.inside) @scope

(for_statement
  body: (block
    (_) @scope.inside)) @scope

(method_declaration
  body: (block
    (_) @scope.inside)) @scope
