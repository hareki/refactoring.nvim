(assignment_expression
  left: (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  left: (member_expression) @reference.identifier
  (#set! reference_type write)
  (#set! field))

(assignment_expression
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(assignment_expression
  right: (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field))

(update_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(update_expression
  (member_expression) @reference.identifier
  (#set! reference_type write)
  (#set! field))

(augmented_assignment_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(augmented_assignment_expression
  (member_expression) @reference.identifier
  (#set! reference_type write)
  (#set! field))

(arguments
  (identifier) @reference.identifier
  (#set! reference_type read))

(arguments
  (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field))

(member_expression
  object: (identifier) @reference.identifier
  (#set! reference_type read))

(member_expression
  (#set! reference_type read)
  (#set! field)) @reference.identifier

(call_expression
  function: (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier))

(call_expression
  function: (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! field)
  (#set! function_call_identifier))

(function_declaration
  name: (_) @reference.identifier
  (#set! declaration)
  (#set! reference_type write))

(method_definition
  name: (_) @reference.identifier
  (#set! declaration)
  (#set! reference_type write))

(pair
  value: (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier))

(pair
  value: (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier)
  (#set! field))

(array
  (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier))

(array
  (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier)
  (#set! field))

(spread_element
  (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier))

(spread_element
  (member_expression) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier)
  (#set! field))
