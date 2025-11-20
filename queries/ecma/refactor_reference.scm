(assignment_expression
  left: (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  left: (member_expression) @reference.identifier
  (#set! reference_type write)
  (#set! field true))

(assignment_expression
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(assignment_expression
  right: (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(update_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(update_expression
  (member_expression) @reference.identifier
  (#set! reference_type write)
  (#set! field true))

(augmented_assignment_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(augmented_assignment_expression
  (member_expression) @reference.identifier
  (#set! reference_type write)
  (#set! field true))

(arguments
  (identifier) @reference.identifier
  (#set! reference_type read))

(arguments
  (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(member_expression
  object: (identifier) @reference.identifier
  (#set! reference_type read))

(member_expression
  (#set! reference_type read)
  (#set! field true)) @reference.identifier

; TODO: remove the full function call everywhere, filter out references that
; are function calls (I may be already doing this). `print_exp` will be used to
; print function calls
(call_expression
  function: (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier true))

(call_expression
  function: (identifier)
  (#set! reference_type read)) @reference.identifier

(call_expression
  function: (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field true)
  (#set! function_call_identifier true))

(call_expression
  function: (member_expression)
  (#set! reference_type read)
  (#set! field true)) @reference.identifier

(function_declaration
  name: (_) @reference.identifier
  (#set! declaration true)
  (#set! reference_type write))

(method_definition
  name: (_) @reference.identifier
  (#set! declaration true)
  (#set! reference_type write))
