(parameters
  (identifier) @reference.identifier
  (#set! declaration))

(parameters
  (default_parameter
    (identifier) @reference.identifier)
  (#set! declaration))

(unlet_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(unlet_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(let_statement
  (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration))

(let_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration)
  (#set! field))

(let_statement
  (list_assignment
    (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration))

(let_statement
  (list_assignment
    [
      (scoped_identifier)
      (argument)
    ] @reference.identifier)
  (#set! reference_type write)
  (#set! declaration)
  (#set! field))

(binary_operation
  (identifier) @reference.identifier
  (#set! reference_type read))

(binary_operation
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(unary_operation
  (identifier) @reference.identifier
  (#set! reference_type read))

(unary_operation
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(if_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(if_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(call_expression
  (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier))

(call_expression
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier)
  (#set! field))

(field_expression
  value: (identifier) @reference.identifier
  (#set! reference_type read))

(field_expression
  value: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(dictionnary_entry
  (identifier) @reference.identifier
  (#set! reference_type read))

(dictionnary_entry
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(index_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(index_expression
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(for_loop
  variable: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration))

(for_loop
  variable: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration)
  (#set! field))

(for_loop
  iter: (identifier) @reference.identifier
  (#set! reference_type read))

(for_loop
  iter: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(while_loop
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(while_loop
  condition: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(echo_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(echo_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(echomsg_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(echomsg_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(function_declaration
  name: (identifier) @reference.identifier
  (#set! declaration))

(function_declaration
  name: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! declaration)
  (#set! field))
