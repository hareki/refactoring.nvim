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
  (#set! field true))

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
    (#set! declaration true)))

; local foo
(variable_declaration
  (variable_list
    name: (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(bracket_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(dot_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(method_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(function_call
  [
    (method_index_expression)
    (dot_index_expression)
    (bracket_index_expression)
  ]
  (#set! reference_type read)
  (#set! field true)) @reference.identifier

(arguments
  (identifier) @reference.identifier
  (#set! reference_type read))

(arguments
  [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(parameters
  (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(function_call
  name: (identifier) @reference.identifier
  (#set! reference_type read))

(function_call
  name: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(expression_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(expression_list
  [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(for_generic_clause
  (variable_list
    name: (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(for_numeric_clause
  name: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(for_numeric_clause
  end: (identifier) @reference.identifier
  (#set! reference_type read))

(for_numeric_clause
  end: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(for_numeric_clause
  start: (identifier) @reference.identifier
  (#set! reference_type read))

(for_numeric_clause
  start: [
    (dot_index_expression)
    (bracket_index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

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
  (#set! field true))

(function_declaration
  name: (_) @reference.identifier
  (#set! declaration true)
  (#set! reference_type write))

