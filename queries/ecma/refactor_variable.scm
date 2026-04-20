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
