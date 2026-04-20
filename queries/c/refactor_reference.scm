(parameter_declaration
  type: (_) @_type
  declarator: (identifier) @reference.identifier
  (#set-type! c @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration))

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
  (#set! declaration))

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
  (#set! declaration))

; int foo;
(declaration
  .
  type: (_) @_type
  .
  (field_expression) @reference.identifier
  .
  (","
    (field_expression) @reference.identifier)*
  (#set-type! c @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration)
  (#set! field))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  (field_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field))

(update_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(update_expression
  (field_expression) @reference.identifier
  (#set! reference_type write)
  (#set! field))

(assignment_expression
  left: (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  left: (field_expression) @reference.identifier
  (#set! reference_type write)
  (#set! field))

(assignment_expression
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(assignment_expression
  right: (field_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field))

(argument_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(argument_list
  (field_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  (field_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field))

(call_expression
  (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier))

(call_expression
  (field_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field)
  (#set! function_call_identifier))

(function_definition
  declarator: (function_declarator
    declarator: (identifier) @reference.identifier)
  (#set! declaration)
  (#set! reference_type write))
