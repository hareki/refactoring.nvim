((variable_declaration
  .
  type: (_) @_type
  .
  (variable_declarator
    name: (_) @reference.identifier)
  .
  (","
    (variable_declarator
      name: (_) @reference.identifier))*)
  (#set-type! c_sharp @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(parameter
  type: (_) @_type
  name: (_) @reference.identifier
  (#set-type! c_sharp @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

; foo = 1
(assignment_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(postfix_unary_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(argument
  (identifier) @reference.identifier
  (#set! reference_type read))

(member_access_expression
  expression: (identifier) @reference.identifier
  (#set! reference_type read))

(invocation_expression
  function: (_) @reference.identifier
  (#set! reference_type read)
  (#set! function_call_identifier true))

(method_declaration
  name: (_) @reference.identifier
  (#set! declaration true)
  (#set! reference_type write))

(local_function_statement
  name: (_) @reference.identifier
  (#set! declaration true)
  (#set! reference_type write))
