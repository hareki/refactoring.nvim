(expression_statement
  (assignment_expression
    left: (list_literal
      .
      (variable_name) @variable.identifier
      .
      ("," @variable.identifier_separator
        (variable_name) @variable.identifier))
    right: (array_creation_expression
      .
      (array_element_initializer
        (_) @variable.value)
      .
      ("," @variable.value_separator
        (array_element_initializer
          (_) @variable.value))))) @variable.declaration

; TODO: because PHP doesn't have a proper declaration statement, each
; assignment is currently interpreted as a declaration, which can lead to
; unexpected behaviour
; $foo = 'foo'
(assignment_expression
  left: (variable_name) @reference.identifier
  right: (_) @_value
  (#infer-type! php @_value)
  (#set! reference_type write)
  (#set! declaration true))

; [$foo, $bar] = ...
(assignment_expression
  left: (list_literal
    .
    (variable_name) @reference.identifier
    (","
      .
      (variable_name) @reference.identifier)*)
  (#set! reference_type write)
  (#set! declaration true))

; [$foo, $bar] = ['foo', 'bar']
(assignment_expression
  left: (list_literal
    .
    (variable_name) @reference.identifier
    (","
      .
      (variable_name) @reference.identifier)*)
  right: (array_creation_expression
    .
    (array_element_initializer
      (_) @_value)
    .
    (","
      .
      (array_element_initializer
        (_) @_value)))
  (#infer-type! php @_value)
  (#set! reference_type write)
  (#set! declaration true))

; $i;
(expression_statement
  (variable_name) @reference.identifier
  (#set! declaration true))

(simple_parameter
  type: (_) @_type
  name: (variable_name) @reference.identifier
  (#set-type! php @_type @reference.identifier)
  (#set! declaration true))

(binary_expression
  (variable_name) @reference.identifier
  (#set! reference_type read))

(update_expression
  (variable_name) @reference.identifier
  (#set! reference_type write))

(augmented_assignment_expression
  left: (variable_name) @reference.identifier
  (#set! reference_type write))

(augmented_assignment_expression
  right: (variable_name) @reference.identifier
  (#set! reference_type read))

(arguments
  (argument
    (variable_name) @reference.identifier)
  (#set! reference_type read))

(print_intrinsic
  (variable_name) @reference.identifier
  (#set! reference_type read))

(return_statement
  (variable_name) @reference.identifier
  (#set! reference_type read))

(echo_statement
  (variable_name) @reference.identifier
  (#set! reference_type read))

(sequence_expression
  (variable_name) @reference.identifier
  (#set! reference_type read))

(parenthesized_expression
  (variable_name) @reference.identifier
  (#set! reference_type read))

(subscript_expression
  (variable_name) @reference.identifier
  (#set! reference_type read))

(member_access_expression
  (variable_name) @reference.identifier
  (#set! reference_type read))

(member_call_expression
  (variable_name) @reference.identifier
  (#set! reference_type read))

(function_call_expression
  function: (variable_name) @reference.identifier
  (#set! reference_type read))
