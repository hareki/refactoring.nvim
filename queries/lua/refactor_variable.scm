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
