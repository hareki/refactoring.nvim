(assignment
  left: (_) @variable.identifier
  right: (_) @variable.value) @variable.declaration

(method) @local.scope

(assignment
  (identifier) @reference.identifier)

(array
  (identifier) @reference.identifier)

(block_parameters
  (identifier) @reference.identifier)

(interpolation
  (identifier) @reference.identifier)

(operator_assignment
  (identifier) @reference.identifier)

(binary
  (identifier) @reference.identifier)

(unary
  (identifier) @reference.identifier)

((comment)* @output.comment
  .
  (method) @output.method)

((comment)* @output.comment
  .
  (singleton_method) @output.method.singleton)

((comment)* @output.comment
  .
  (method) @output.function)

((comment)* @output.comment
  .
  (singleton_method) @output.function.singleton)

(class) @local.scope

[
  (block)
  (do_block)
] @local.scope
