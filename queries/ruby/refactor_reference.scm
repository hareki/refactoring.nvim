(method_parameters
  (identifier) @reference.identifier
  (#set! declaration))

; foo = ...
(assignment
  left: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration))

; ... = foo
(assignment
  right: (identifier) @reference.identifier
  (#set! reference_type read))

; foo, bar = ...
(assignment
  left: (left_assignment_list
    (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration))

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
  (#set! declaration))

(binary
  (identifier) @reference.identifier
  (#set! reference_type read))

(unary
  (identifier) @reference.identifier
  (#set! reference_type read))

(for
  pattern: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration))

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
  (#set! reference_type read)
  (#set! function_call_identifier))

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

(call
  method: (_) @reference.identifier
  (#set! reference_type read))

(method
  name: (_) @reference.identifier
  (#set! reference_type write)
  (#set! declaration))
