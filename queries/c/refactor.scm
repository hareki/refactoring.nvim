(declaration
  .
  (_)
  .
  declarator: (init_declarator
    declarator: (_) @variable.identifier
    value: (_) @variable.value)
  .
  (","
    declarator: (init_declarator
      declarator: (_) @variable.identifier
      value: (_) @variable.value))*) @variable.declaration

(declaration
  (init_declarator
    (identifier) @reference.identifier))

(declaration
  (identifier) @reference.identifier)

(binary_expression
  (identifier) @reference.identifier)

(update_expression
  (identifier) @reference.identifier)

(assignment_expression
  (identifier) @reference.identifier)

(argument_list
  (identifier) @reference.identifier)

(return_statement
  (identifier) @reference.identifier)

(call_expression
  (identifier) @reference.identifier)

((comment)* @output.comment
  .
  (function_definition) @output.function)

[
  (for_statement)
  (if_statement)
  (while_statement)
  (translation_unit)
  (function_definition)
  (compound_statement)
  (struct_specifier)
] @scope
