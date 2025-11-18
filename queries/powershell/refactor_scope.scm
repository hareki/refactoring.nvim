(class_statement
  (class_method_definition) @scope.inside) @scope

(class_method_definition
  (script_block) @scope.inside) @scope

(statement_block
  (statement_list) @scope.inside) @scope

(function_statement
  (script_block) @scope.inside) @scope

(script_block_expression
  (script_block) @scope.inside) @scope

(program) @scope
