(parameters
  (identifier) @reference.identifier
  (#set! declaration true))

(parameters
  (default_parameter
    (identifier) @reference.identifier)
  (#set! declaration true))

(unlet_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(unlet_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(let_statement
  (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(let_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true)
  (#set! field true))

(let_statement
  (list_assignment
    (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(let_statement
  (list_assignment
    [
      (scoped_identifier)
      (argument)
    ] @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true)
  (#set! field true))

(binary_operation
  (identifier) @reference.identifier
  (#set! reference_type read))

(binary_operation
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(unary_operation
  (identifier) @reference.identifier
  (#set! reference_type read))

(unary_operation
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(if_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(if_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(call_expression
  (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier true))

(call_expression
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier true)
  (#set! field true))

(field_expression
  value: (identifier) @reference.identifier
  (#set! reference_type read))

(field_expression
  value: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(dictionnary_entry
  (identifier) @reference.identifier
  (#set! reference_type read))

(dictionnary_entry
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(index_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(index_expression
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(for_loop
  variable: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(for_loop
  variable: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true)
  (#set! field true))

(for_loop
  iter: (identifier) @reference.identifier
  (#set! reference_type read))

(for_loop
  iter: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(while_loop
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(while_loop
  condition: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(echo_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(echo_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(echomsg_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(echomsg_statement
  [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(function_declaration
  name: (identifier) @reference.identifier
  (#set! declaration true))

(function_declaration
  name: [
    (scoped_identifier)
    (argument)
  ] @reference.identifier
  (#set! declaration true)
  (#set! field true))
