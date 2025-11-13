(parameter_declaration
  type: (_) @_type
  declarator: (identifier) @reference.identifier
  (#set-type! c @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

; int foo = 1;
(declaration
  .
  type: (_) @_type
  .
  declarator: (init_declarator
    declarator: (_) @reference.identifier)
  .
  (","
    declarator: (init_declarator
      declarator: (_) @reference.identifier))*
  (#set-type! c @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

; int foo;
(declaration
  .
  type: (_) @_type
  .
  (identifier) @reference.identifier
  .
  (","
    (identifier) @reference.identifier)*
  (#set-type! c @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(update_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(argument_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(call_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

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

(translation_unit
  _*
  (comment)* @output_function.comment
  .
  (function_definition) @output_function)
