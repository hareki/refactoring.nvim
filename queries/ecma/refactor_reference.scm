(assignment_expression
  left: [
    (identifier)
    (member_expression)
  ] @reference.identifier
  (#set! reference_type write))

(assignment_expression
  right: [
    (identifier)
    (member_expression)
  ] @reference.identifier
  (#set! reference_type read))

(binary_expression
  [
    (identifier)
    (member_expression)
  ] @reference.identifier
  (#set! reference_type read))

(update_expression
  [
    (identifier)
    (member_expression)
  ] @reference.identifier
  (#set! reference_type write))

(augmented_assignment_expression
  [
    (identifier)
    (member_expression)
  ] @reference.identifier
  (#set! reference_type write))

(arguments
  [
    (identifier)
    (member_expression)
  ] @reference.identifier
  (#set! reference_type read))

(return_statement
  [
    (identifier)
    (member_expression)
  ] @reference.identifier
  (#set! reference_type read))

(member_expression
  object: [
    (identifier)
    (member_expression)
  ] @reference.identifier
  (#set! reference_type read))

(call_expression
  function: (_) @reference.identifier
  (#set! reference_type read))

(function_declaration
  name: (_) @reference.identifier
  (#set! declaration true)
  (#set! reference_type write))

(method_definition
  name: (_) @reference.identifier
  (#set! declaration true)
  (#set! reference_type write))
