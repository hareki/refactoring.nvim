(struct_specifier) @scope @scope.inside @scope.outside

(function_definition
  declarator: (function_declarator
    parameters: (parameter_list) @scope)
  body: (compound_statement
    .
    (_) @scope.inside) @scope) @scope.outside

(translation_unit) @scope @scope.inside @scope.outside

(while_statement
  body: (compound_statement
    .
    (_) @scope.inside)) @scope @scope.outside

(for_statement
  body: (compound_statement
    .
    (_) @scope.inside)) @scope @scope.outside

(if_statement
  consequence: (_) @scope @scope.inside) @scope.outside

(if_statement
  alternative: (else_clause
    (_) @scope @scope.inside)) @scope.outside
