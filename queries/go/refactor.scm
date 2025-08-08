(short_var_declaration
  left: (expression_list
    (identifier) @variable.identifier)
  right: (expression_list
    (_) @variable.value)) @variable.declaration

(var_declaration
  (var_spec
    name: (identifier) @variable.identifier
    value: (_) @variable.value)) @variable.declaration
