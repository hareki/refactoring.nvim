(let_statement
  (identifier) @variable.identifier
  .
  (_) @variable.value) @variable.declaration

(let_statement
  (scoped_identifier) @variable.identifier
  .
  (_) @variable.value) @variable.declaration

(parameters
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! declaration true))

(unlet_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(let_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(let_statement
  (list_assignment
    [
      (identifier)
      (scoped_identifier)
    ] @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(binary_operation
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(unary_operation
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(if_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(return_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(call_expression
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(field_expression
  value: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(argument
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(dictionnary_entry
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(index_expression
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(for_loop
  variable: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(for_loop
  iter: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(while_loop
  condition: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(echo_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(function_definition) @output.function

(script_file) @scope

(function_definition
  (body) @scope.inside) @scope
