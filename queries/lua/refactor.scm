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
