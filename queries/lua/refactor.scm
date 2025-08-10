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

(variable_list
  name: (identifier) @reference.identifier)

(bracket_index_expression
  table: (identifier) @reference.identifier)

(dot_index_expression
  table: (identifier) @reference.identifier)

(method_index_expression
  table: (identifier) @reference.identifier)

(arguments
  (identifier) @reference.identifier)

(function_call
  name: (identifier) @reference.identifier)

(expression_list
  (identifier) @reference.identifier)

(binary_expression
  (identifier) @reference.identifier)

(for_numeric_clause
  (identifier) @reference.identifier)

((comment)* @output.comment
  .
  (assignment_statement
    (expression_list
      (function_definition))) @output.function)

((comment)* @output.comment
  .
  (function_declaration) @output.function)
