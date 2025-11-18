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

(inc_statement
  (identifier) @reference.identifier
  (#set! reference_type write))

(argument_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(selector_expression
  operand: (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  (expression_list
    (identifier) @reference.identifier)
  (#set! reference_type read))

(assignment_statement
  left: (expression_list
    (identifier) @reference.identifier)
  (#set! reference_type write))

(assignment_statement
  right: (expression_list
    (identifier) @reference.identifier)
  (#set! reference_type read))

(index_expression
  operand: (identifier) @reference.identifier
  (#set! reference_type read))

(call_expression
  function: (identifier) @reference.identifier
  (#set! reference_type read))
