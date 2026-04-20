(declaration
  .
  type: (_)
  .
  declarator: (init_declarator
    declarator: (_) @variable.identifier
    "=" @variable.value_separator
    value: (_) @variable.value)
  .
  ("," @variable.identifier_separator
    declarator: (init_declarator
      declarator: (_) @variable.identifier
      "=" @variable.value_separator
      value: (_) @variable.value))*) @variable.declaration
