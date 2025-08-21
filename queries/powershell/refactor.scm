(assignment_expression
  .
  (_) @variable.identifier
  value: (_) @variable.value) @variable.declaration

(unary_expression
  (variable) @reference.identifier)

(unary_expression
  (_
    (variable) @reference.identifier))

((comment)* @output.comment
  .
  (statement_list
    (function_statement) @output.function))

((comment)* @output.comment
  .
  (class_method_definition) @output.method)

(class_statement) @local.scope

(class_method_definition) @local.scope

(statement_block) @local.scope

(function_statement) @local.scope
