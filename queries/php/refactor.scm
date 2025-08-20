(expression_statement
  (assignment_expression
    left: (variable_name) @variable.identifier
    right: (_) @variable.value)) @variable.declaration

(assignment_expression
  left: (variable_name
    (name) @reference.identifier))

(binary_expression
  (variable_name
    (name) @reference.identifier))

(update_expression
  (variable_name
    (name) @reference.identifier))

(augmented_assignment_expression
  (variable_name
    (name) @reference.identifier))

(arguments
  (argument
    (variable_name
      (name) @reference.identifier)))

(print_intrinsic
  (variable_name
    (name) @reference.identifier))

(return_statement
  (variable_name
    (name) @reference.identifier))

((comment)* @output.comment
  .
  (method_declaration) @output.method)

((comment)* @output.comment
  .
  (function_definition) @output.function)

(class_declaration) @scope

(method_declaration) @scope

(function_definition) @scope

(anonymous_function) @scope
