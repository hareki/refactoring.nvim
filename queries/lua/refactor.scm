; variable
(variable_declaration
  (assignment_statement
    (variable_list
      name: (identifier) @variable.identifier)
    (expression_list
      value: (_) @variable.value))) @variable.declaration

(assignment_statement
  (variable_list
    name: (dot_index_expression) @variable.identifier)
  (expression_list
    value: (_) @variable.value)) @variable.declaration
