(declaration
  .
  (_)
  .
  declarator: (init_declarator
    declarator: (_) @variable.identifier
    value: (_) @variable.value)
  .
  (","
    declarator: (init_declarator
      declarator: (_) @variable.identifier
      value: (_) @variable.value))*) @variable.declaration

(parameter_declaration
  type: (_) @_type
  declarator: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set-type! c @_type @reference.identifier)
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
  (#set! reference_type write)
  (#set-type! c @_type @reference.identifier)
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
  (#set! reference_type write)
  (#set-type! c @_type @reference.identifier)
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
  (if_statement)
  (while_statement)
  (translation_unit)
  (function_definition)
  (compound_statement)
  (struct_specifier)
] @scope
