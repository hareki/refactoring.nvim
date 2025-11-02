; NOTE: we don't support the same for object destructuring because we rely on
; the order of identifiers and values to match them together.
; let [foo, bar] = ['foo', 'bar']
(lexical_declaration
  (variable_declarator
    name: (array_pattern
      .
      (identifier) @variable.identifier
      .
      ("," @variable.identifier_separator
        (identifier) @variable.identifier)*)
    value: (array
      .
      (_) @variable.value
      .
      ("," @variable.value_separator
        (_) @variable.value)*))) @variable.declaration

; let foo = 'foo'
(lexical_declaration
  (variable_declarator
    name: (identifier) @variable.identifier
    value: (_) @variable.value)) @variable.declaration

(assignment_expression
  left: (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(update_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(augmented_assignment_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(arguments
  (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(member_expression
  object: (identifier) @reference.identifier
  (#set! reference_type read))
