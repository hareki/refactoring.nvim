(program
  (php_tag)
  .
  (_) @scope.inside) @scope

(class_declaration
  body: (declaration_list
    .
    (_) @scope.inside)) @scope

(method_declaration
  body: (compound_statement
    .
    (_) @scope.inside)) @scope

(function_definition
  body: (compound_statement
    .
    (_) @scope.inside)) @scope

(anonymous_function
  body: (compound_statement
    .
    (_) @scope.inside)) @scope
