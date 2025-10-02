; TODO: change to support multiple variables after changing how anonymous nodes
; are deleted/queried for in other languages
(local_variable_declaration
  declarator: (variable_declarator
    name: (identifier) @variable.identifier
    value: (_) @variable.value)) @variable.declaration

(local_variable_declaration
  type: (_) @_type
  .
  declarator: (variable_declarator
    name: (identifier) @reference.identifier)
  .
  (","
    .
    declarator: (variable_declarator
      name: (identifier) @reference.identifier))*
  (#set-type! java @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(argument_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(update_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  left: (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(array_access
  array: (identifier) @reference.identifier
  (#set! reference_type read))

(field_access
  object: (identifier) @reference.identifier
  (#set! reference_type read))

(method_invocation
  object: (identifier) @reference.identifier
  (#set! reference_type read))

; if/while/do while
(_
  condition: (parenthesized_expression
    (identifier) @reference.identifier
    (#set! reference_type read)))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(formal_parameter
  type: (_) @_type
  name: (identifier) @reference.identifier
  (#set-type! java @_type @reference.identifier)
  (#set! declaration true))

([
  (line_comment)
  (block_comment)
]* @output.comment
  .
  (method_declaration) @output.method)

(program) @scope

(class_declaration) @scope

(record_declaration) @scope

(enum_declaration) @scope

(lambda_expression) @scope

(enhanced_for_statement) @scope

(block) @scope

(if_statement) @scope

(if_statement
  consequence: (_) @scope)

(if_statement
  alternative: (_) @scope)

(try_statement) @scope

(catch_clause) @scope

(for_statement) @scope

(for_statement) @scope

(do_statement) @scope

(while_statement) @scope

(constructor_declaration) @scope

(method_declaration) @scope
