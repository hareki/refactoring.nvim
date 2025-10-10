(declaration
  .
  type: (_)
  .
  declarator: (init_declarator
    declarator: (_) @variable.identifier
    "=" @variable.value_separator
    value: (_) @variable.value)
  .
  ("," @variable.identifier_separator
    declarator: (init_declarator
      declarator: (_) @variable.identifier
      "=" @variable.value_separator
      value: (_) @variable.value))*) @variable.declaration

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

((comment)* @output.comment
  .
  (function_definition) @output.function)

[
  (for_statement)
  (while_statement)
  (translation_unit)
  (function_definition)
  (struct_specifier)
] @scope

(if_statement
  consequence: (_) @scope) @scope.outside

(if_statement
  alternative: (else_clause
    (_) @scope)) @scope.outside
