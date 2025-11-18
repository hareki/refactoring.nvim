(local_variable_declaration
  type: (_) @_type
  .
  declarator: (variable_declarator
    name: (identifier) @reference.identifier)
  .
  (","
    .
    declarator: (variable_declarator
      name: (identifier) @reference.identifier))*
  (#set-type! java @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(argument_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(update_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  left: (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(array_access
  array: (identifier) @reference.identifier
  (#set! reference_type read))

(field_access
  object: (identifier) @reference.identifier
  (#set! reference_type read))

(method_invocation
  object: (identifier) @reference.identifier
  (#set! reference_type read))

; if/while/do while
(_
  condition: (parenthesized_expression
    (identifier) @reference.identifier
    (#set! reference_type read)))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(formal_parameter
  type: (_) @_type
  name: (identifier) @reference.identifier
  (#set-type! java @_type @reference.identifier)
  (#set! declaration true))
