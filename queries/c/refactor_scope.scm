(struct_specifier) @scope

(function_definition
  body: (compound_statement
    .
    (_) @scope.inside)) @scope

(translation_unit) @scope

(while_statement
  body: (compound_statement
    .
    (_) @scope.inside)) @scope

(for_statement
  body: (compound_statement
    .
    (_) @scope.inside)) @scope

(if_statement
  consequence: (_) @scope) @scope.outside

(if_statement
  alternative: (else_clause
    (_) @scope)) @scope.outside
