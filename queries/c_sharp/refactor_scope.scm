(method_declaration
  parameters: (parameter_list) @scope
  body: (block
    .
    (_) @scope.inside) @scope) @scope.outside

(local_function_statement
  parameters: (parameter_list) @scope
  body: (block
    .
    (_) @scope.inside) @scope) @scope.outside

(_
  (block
    .
    (_) @scope.inside) @_block
  (#not-has-parent? @_block local_function_statement)
  (#not-has-parent? @_block method_declaration)) @scope @scope.outside

(class_declaration
  body: (declaration_list
    (_) @scope.inside) @scope) @scope.outside
