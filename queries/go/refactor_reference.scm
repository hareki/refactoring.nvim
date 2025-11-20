(parameter_declaration
  name: (identifier) @reference.identifier
  type: (type_identifier) @_type
  (#set-type! go @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

; var foo int
(var_spec
  name: (identifier) @reference.identifier
  type: (_) @_type
  (#set-type! go @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

; var foo int = bar
(var_spec
  value: (expression_list
    (identifier) @reference.identifier)
  (#set! reference_type read))

; foo := 2
(short_var_declaration
  left: (expression_list
    .
    (identifier) @reference.identifier
    .
    (","
      (identifier) @reference.identifier)*)
  right: (expression_list
    .
    (_) @_value
    .
    (","
      (_) @_value)*)
  (#infer-type! go @_value)
  (#set! reference_type write)
  (#set! declaration true))

; foo := bar
(short_var_declaration
  right: (expression_list
    (identifier) @reference.identifier)
  (#set! reference_type read))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  [
    (selector_expression)
    (index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(inc_statement
  (identifier) @reference.identifier
  (#set! reference_type write))

(inc_statement
  [
    (selector_expression)
    (index_expression)
  ] @reference.identifier
  (#set! reference_type write)
  (#set! field true))

(argument_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(argument_list
  [
    (selector_expression)
    (index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(selector_expression
  operand: (identifier) @reference.identifier
  (#set! reference_type read))

(selector_expression
  operand: [
    (selector_expression)
    (index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(return_statement
  (expression_list
    (identifier) @reference.identifier)
  (#set! reference_type read))

(return_statement
  (expression_list
    [
      (selector_expression)
      (index_expression)
    ] @reference.identifier
    (#set! field true))
  (#set! reference_type read))

(assignment_statement
  left: (expression_list
    (identifier) @reference.identifier)
  (#set! reference_type write))

(assignment_statement
  left: (expression_list
    [
      (selector_expression)
      (index_expression)
    ] @reference.identifier
    (#set! field true))
  (#set! reference_type write))

(assignment_statement
  right: (expression_list
    (identifier) @reference.identifier)
  (#set! reference_type read))

(assignment_statement
  right: (expression_list
    [
      (selector_expression)
      (index_expression)
    ] @reference.identifier
    (#set! field true))
  (#set! reference_type read))

(index_expression
  operand: (identifier) @reference.identifier
  (#set! reference_type read))

(index_expression
  operand: [
    (selector_expression)
    (index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

(call_expression
  function: (identifier) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier true))

(call_expression
  function: [
    (selector_expression)
    (index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true)
  (#set! function_call_identifier true))

(if_statement
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(if_statement
  condition: [
    (selector_expression)
    (index_expression)
  ] @reference.identifier
  (#set! reference_type read)
  (#set! field true))

; NOTE: method_declaration is purposefully not included because it doesn't
; create a top.level identifier
(function_declaration
  name: (_) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))
