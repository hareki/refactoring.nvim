; TODO: configure ts_query_ls for the repo once all the captures and predicates are stable-ish
; local foo = 'foo'
(variable_declaration
  (assignment_statement
    (variable_list
      .
      name: (identifier) @variable.identifier
      .
      ("," @variable.identifier_separator
        .
        name: (identifier) @variable.identifier)*)
    (expression_list
      .
      value: (_) @variable.value
      .
      ("," @variable.value_separator
        .
        value: (_) @variable.value)*))) @variable.declaration

; TODO: fix for multiple assignments
; foo.bar = 'bar'
(assignment_statement
  (variable_list
    name: (dot_index_expression) @variable.identifier)
  (expression_list
    value: (_) @variable.value)) @variable.declaration

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
  (#set! declaration true))

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
  (method_index_expression)
  (#set! reference_type read)) @reference.identifier

(arguments
  [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(parameters
  [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(function_call
  name: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(expression_list
  [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(binary_expression
  [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(for_generic_clause
  (variable_list
    name: (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(for_numeric_clause
  name: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(for_numeric_clause
  end: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(for_numeric_clause
  start: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

; repeat until/while/if
(_
  condition: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))
