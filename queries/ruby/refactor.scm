(assignment
  left: (_) @variable.identifier
  right: (_) @variable.value) @variable.declaration

(method_parameters
  (identifier) @reference.identifier
  (#set! declaration true))

; foo = ...
(assignment
  left: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

; ... = foo
(assignment
  right: (identifier) @reference.identifier
  (#set! reference_type read))

; foo, bar = ...
(assignment
  left: (left_assignment_list
    (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(array
  (identifier) @reference.identifier
  (#set! reference_type read))

(block_parameters
  (identifier) @reference.identifier
  (#set! reference_type read))

(interpolation
  (identifier) @reference.identifier
  (#set! reference_type read))

(operator_assignment
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(operator_assignment
  left: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(binary
  (identifier) @reference.identifier
  (#set! reference_type read))

(unary
  (identifier) @reference.identifier
  (#set! reference_type read))

(for
  pattern: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(for
  value: (in
    (identifier) @reference.identifier)
  (#set! reference_type read))

(for
  value: (in
    (range
      (identifier)) @reference.identifier)
  (#set! reference_type read))

(call
  arguments: (argument_list
    (identifier) @reference.identifier)
  (#set! reference_type read))

(element_reference
  object: (identifier) @reference.identifier
  (#set! reference_type read))

(call
  receiver: (identifier) @reference.identifier
  (#set! reference_type read))

(if
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(while
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(until
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(if_modifier
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(return
  (argument_list
    (identifier) @reference.identifier)
  (#set! reference_type read))

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

(program) @scope

(method
  body: (_) @scope.inside) @scope

(class
  body: (body_statement) @scope.inside) @scope
