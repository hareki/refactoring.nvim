(assignment
  left: [
    (identifier)
    (attribute)
  ] @variable.identifier
  right: (_) @variable.value) @variable.declaration

(assignment
  left: [
    (pattern_list
      (identifier) @variable.identifier)
    (tuple_pattern
      (identifier) @variable.identifier)
  ]
  right: (expression_list
    (_) @variable.value)) @variable.declaration
