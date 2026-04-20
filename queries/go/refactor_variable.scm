(short_var_declaration
  left: (expression_list
    .
    (identifier) @variable.identifier
    .
    ("," @variable.identifier_separator
      (identifier) @variable.identifier)*)
  right: (expression_list
    .
    (_) @variable.value
    .
    ("," @variable.value_separator
      (_) @variable.value)*)) @variable.declaration
