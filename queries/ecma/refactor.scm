; NOTE: we don't support the same for object destructuring because we rely on
; the order of identifiers and values to match them together.
; let [foo, bar] = ['foo', 'bar']
(lexical_declaration
  (variable_declarator
    name: (array_pattern
      .
      (identifier) @variable.identifier
      .
      (","
        (identifier) @variable.identifier)*)
    value: (array
      .
      (_) @variable.value
      .
      (","
        (_) @variable.value)*))) @variable.declaration

; let foo = 'foo'
(lexical_declaration
  (variable_declarator
    name: (identifier) @variable.identifier
    value: (_) @variable.value)) @variable.declaration

(variable_declarator
  (identifier) @reference.identifier)

(binary_expression
  (identifier) @reference.identifier)

(update_expression
  (identifier) @reference.identifier)

(augmented_assignment_expression
  (identifier) @reference.identifier)

(arguments
  (identifier) @reference.identifier)

((comment)* @output.comment
  .
  (function_declaration) @output.function)

((comment)* @output.comment
  .
  (lexical_declaration
    (variable_declarator
      (arrow_function))) @output.function)

((comment)* @output.comment
  .
  (method_definition) @output.method)

(statement_block) @scope

(function_expression) @scope

(arrow_function) @scope

(function_declaration) @scope

(method_definition) @scope

(for_statement) @scope

(for_in_statement) @scope

(catch_clause) @scope
