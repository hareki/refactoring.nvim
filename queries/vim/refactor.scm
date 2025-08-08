(let_statement
  (identifier) @variable.identifier
  (_) @variable.value) @variable.declaration

(let_statement
  (scoped_identifier) @variable.identifier
  (_) @variable.value) @variable.declaration
