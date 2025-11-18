(assignment_expression
  left: (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(update_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(augmented_assignment_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(arguments
  (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(member_expression
  object: (identifier) @reference.identifier
  (#set! reference_type read))
