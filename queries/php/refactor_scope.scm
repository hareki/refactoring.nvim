(program
  (php_tag)
  .
  (_) @scope.inside) @scope @scope.outside

(class_declaration
  body: (declaration_list
    .
    (_) @scope.inside)) @scope @scope.outside

(method_declaration
  parameters: (_) @scope
  body: (compound_statement
    .
    (_) @scope.inside) @scope) @scope.outside

(function_definition
  parameters: (_) @scope
  body: (compound_statement
    .
    (_) @scope.inside) @scope) @scope.outside

(anonymous_function
  body: (compound_statement
    .
    (_) @scope.inside)) @scope @scope.outside
