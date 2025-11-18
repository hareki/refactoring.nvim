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
