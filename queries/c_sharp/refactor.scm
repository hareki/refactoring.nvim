(local_declaration_statement
  (variable_declaration
    .
    type: (_)
    .
    (variable_declarator
      name: (_) @variable.identifier
      "=" @variable.value_separator
      (_) @variable.value .)
    .
    ("," @variable.identifier_separator
      (variable_declarator
        name: (_) @variable.identifier
        "=" @variable.value_separator
        (_) @variable.value .))*)) @variable.declaration

((variable_declaration
  .
  type: (_) @_type
  .
  (variable_declarator
    name: (_) @reference.identifier)
  .
  (","
    (variable_declarator
      name: (_) @reference.identifier))*)
  (#set-type! c_sharp @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(parameter
  type: (_) @_type
  name: (_) @reference.identifier
  (#set-type! c_sharp @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

; foo = 1
(assignment_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(postfix_unary_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(argument
  (identifier) @reference.identifier
  (#set! reference_type read))

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

(_
  (block)) @scope
