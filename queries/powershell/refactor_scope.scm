(class_statement
  .
  (simple_name)
  .
  (class_method_definition) @scope.inside) @scope @scope.outside

(class_method_definition
  (class_method_parameter_list)? @scope
  (script_block) @scope.inside @scope) @scope.outside

(statement_block
  (statement_list) @scope.inside) @scope @scope.outside

(function_statement
  (script_block) @scope.inside @scope) @scope.outside

(script_block_expression
  (script_block) @scope.inside) @scope @scope.outside

(program) @scope.inside @scope @scope.outside
