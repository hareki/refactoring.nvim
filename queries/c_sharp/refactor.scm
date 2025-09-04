; TODO: clean reference @query similar to @variable ones on every language
; TODO: add support for write/read and declaration for every language
; TODO: add support for type queries (`set-type!` or `infer-type!`) for every language
(local_declaration_statement
  (variable_declaration
    .
    type: (_)
    .
    (variable_declarator
      name: (_) @variable.identifier
      (_) @variable.value .)
    .
    (","
      (variable_declarator
        (_) @variable.identifier
        .
        (_) @variable.value .))*)) @variable.declaration

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
