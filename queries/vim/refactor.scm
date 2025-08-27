(let_statement
  (identifier) @variable.identifier
  .
  (_) @variable.value) @variable.declaration

(let_statement
  (scoped_identifier) @variable.identifier
  .
  (_) @variable.value) @variable.declaration

(unlet_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(let_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(binary_operation
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(unary_operation
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(if_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(return_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(call_expression
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(field_expression
  value: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(argument
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(dictionnary_entry
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(index_expression
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(for_loop
  variable: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier)

(function_definition) @output.function

[
  (script_file)
  (function_definition)
] @scope
