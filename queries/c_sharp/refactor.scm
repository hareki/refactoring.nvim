(local_declaration_statement
  (variable_declaration
    (variable_declarator
      name: (_) @variable.identifier
      (_) @variable.value .))) @variable.declaration

(expression_statement
  (assignment_expression
    left: (_) @variable.identifier
    right: (_) @variable.value)) @variable.declaration

(variable_declarator
  (identifier) @reference.identifier)

(binary_expression
  (identifier) @reference.identifier)

(postfix_unary_expression
  (identifier) @reference.identifier)

(assignment_expression
  (identifier) @reference.identifier)

((comment)* @output.comment
  .
  (_
    (local_function_statement)) @output.function)

((comment)* @output.comment
  .
  [
    (method_declaration)
    (constructor_declaration)
  ] @output.method)

(block) @scope
