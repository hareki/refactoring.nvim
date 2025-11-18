(local_variable_declaration
  .
  type: (_)
  .
  declarator: (variable_declarator
    name: (identifier) @variable.identifier
    "=" @variable.value_separator
    value: (_) @variable.value)
  .
  ("," @variable.identifier_separator
    declarator: (variable_declarator
      name: (identifier) @variable.identifier
      "=" @variable.value_separator
      value: (_) @variable.value))) @variable.declaration
