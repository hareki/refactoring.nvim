(local_declaration_statement
  (variable_declaration
    (variable_declarator
      name: (_) @variable.identifier
      (_) @variable.value .))) @variable.declaration

(expression_statement
  (assignment_expression
    left: (_) @variable.identifier
    right: (_) @variable.value)) @variable.declaration
