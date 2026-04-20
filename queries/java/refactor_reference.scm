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
  (#set! declaration))

(argument_list
  [
    (identifier)
    (field_access)
  ] @reference.identifier
  (#set! reference_type read))

(update_expression
  [
    (identifier)
    (field_access)
  ] @reference.identifier
  (#set! reference_type write))

(assignment_expression
  left: [
    (identifier)
    (field_access)
  ] @reference.identifier
  (#set! reference_type write))

(assignment_expression
  right: [
    (identifier)
    (field_access)
  ] @reference.identifier
  (#set! reference_type read))

(binary_expression
  [
    (identifier)
    (field_access)
  ] @reference.identifier
  (#set! reference_type read))

(array_access
  array: [
    (identifier)
    (field_access)
  ] @reference.identifier
  (#set! reference_type read))

(field_access
  object: [
    (identifier)
    (field_access)
  ] @reference.identifier
  (#set! reference_type read))

(method_invocation
  object: [
    (identifier)
    (field_access)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier))

; if/while/do while
(_
  condition: (parenthesized_expression
    [
      (identifier)
      (field_access)
    ] @reference.identifier
    (#set! reference_type read)))

(return_statement
  [
    (identifier)
    (field_access)
  ] @reference.identifier
  (#set! reference_type read))

(formal_parameter
  type: (_) @_type
  name: (identifier) @reference.identifier
  (#set-type! java @_type @reference.identifier)
  (#set! declaration)
  (#set! reference_type write))

(method_declaration
  name: (_) @reference.identifier
  (#set! declaration)
  (#set! reference_type write))
