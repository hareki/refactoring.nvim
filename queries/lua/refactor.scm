; local foo = 'foo'
(variable_declaration
  (assignment_statement
    (variable_list
      name: (identifier) @variable.identifier
      (","
        name: (identifier) @variable.identifier)*)
    (expression_list
      value: (_) @variable.value
      (","
        value: (_) @variable.value)*))) @variable.declaration

; foo.bar = 'bar'
(assignment_statement
  (variable_list
    name: (dot_index_expression) @variable.identifier)
  (expression_list
    value: (_) @variable.value)) @variable.declaration

; TODO: maybe join @reference and @variable queries in all languages(?
; TODO: this will cause duplicate matches with the capture above (because
; I can't negate ta parent). Will this cause issues?
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
  (#set! eeeeeeece_type read))

(dot_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(method_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(arguments
  (identifier) @reference.identifier
  (#set! reference_type read))

(parameters
  (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(function_call
  name: (identifier) @reference.identifier
  (#set! reference_type read))

(expression_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(for_numeric_clause
  (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

((comment)* @output.comment
  .
  (assignment_statement
    (expression_list
      (function_definition))) @output.function)

((comment)* @output.comment
  .
  (function_declaration) @output.function)

[
  (chunk)
  (do_statement)
  (while_statement)
  (repeat_statement)
  (if_statement)
  (for_statement)
  (function_declaration)
  (function_definition)
] @scope
