(expression_statement
  (assignment_expression
    left: (list_literal
      .
      (variable_name) @variable.identifier
      .
      ("," @variable.identifier_separator
        (variable_name) @variable.identifier))
    right: (array_creation_expression
      .
      (array_element_initializer
        (_) @variable.value)
      .
      ("," @variable.value_separator
        (array_element_initializer
          (_) @variable.value))))) @variable.declaration
