; foo = bar
(assignment_statement
  (variable_list
    name: (identifier) @reference.identifier
    (","
      name: (identifier) @reference.identifier)*)
  (expression_list
    value: (_) @_value
    (","
      value: (_) @_value)*)
  (#infer-type! lua @_value)
  (#set! reference_type write))

; foo.bar = 'bar'
(assignment_statement
  (variable_list
    name: [
      (dot_index_expression)
      (bracket_index_expression)
    ] @reference.identifier
    (","
      name: [
        (dot_index_expression)
        (bracket_index_expression)
      ] @reference.identifier)*)
  (expression_list
    value: (_) @_value
    (","
      value: (_) @_value)*)
  (#infer-type! lua @_value)
  (#set! reference_type write)
  (#set! field))

; local foo = bar
(variable_declaration
  (assignment_statement
    (variable_list
      name: (identifier) @reference.identifier
      (","
        name: (identifier) @reference.identifier)*)
    (expression_list
      value: (_) @_value
      (","
        value: (_) @_value)*)
    (#infer-type! lua @_value)
    (#set! reference_type write)
    (#set! declaration)))

; local foo
(variable_declaration
  (variable_list
    name: (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration))

(bracket_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(bracket_index_expression
  table: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(bracket_index_expression
  field: (identifier) @reference.identifier
  (#set! reference_type read))

(dot_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(dot_index_expression
  table: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(method_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(method_index_expression
  table: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(arguments
  (identifier) @reference.identifier
  (#set! reference_type read))

(arguments
  [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(parameters
  (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration))

(function_call
  name: (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier))

(function_call
  name: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field)
  (#set! function_call_identifier))

(expression_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(expression_list
  [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(for_generic_clause
  (variable_list
    name: (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration))

(for_numeric_clause
  name: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration))

(for_numeric_clause
  end: (identifier) @reference.identifier
  (#set! reference_type read))

(for_numeric_clause
  end: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(for_numeric_clause
  start: (identifier) @reference.identifier
  (#set! reference_type read))

(for_numeric_clause
  start: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

; repeat until/while/if
(_
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(_
  condition: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(function_declaration
  name: (_) @reference.identifier
  (#set! declaration)
  (#set! reference_type write))

(field
  value: (identifier) @reference.identifier
  (#set! reference_type read))

(field
  value: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))

(unary_expression
  operand: (identifier) @reference.identifier
  (#set! reference_type read))

(unary_expression
  operand: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field))
