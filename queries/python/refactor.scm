(assignment
  left: [
    (identifier)
    (attribute)
  ] @variable.identifier
  right: (_) @variable.value) @variable.declaration

(assignment
  left: [
    (pattern_list
      .
      (identifier) @variable.identifier
      .
      ("," @variable.identifier_separator
        .
        (identifier) @variable.identifier)*)
    (tuple_pattern
      .
      (identifier) @variable.identifier
      .
      ("," @variable.identifier_separator
        .
        (identifier) @variable.identifier))
  ]
  right: [
    (expression_list
      .
      (_) @variable.value
      .
      ("," @variable.value_separator
        .
        (_) @variable.value))
    (tuple
      .
      (_) @variable.value
      .
      ("," @variable.value_separator
        .
        (_) @variable.value)*)
  ]) @variable.declaration

(typed_parameter
  (identifier) @reference.identifier
  type: (_) @_type
  (#set-type! python @_type @reference.identifier)
  (#set! declaration true))

(parameters
  (identifier) @reference.identifier
  (#set! declaration true))

(assignment
  left: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(assignment
  right: (identifier) @reference.identifier
  (#set! reference_type read))

; [foo, bar] = ... / (foo, bar) = ...
(assignment
  left: (_
    (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(binary_operator
  (identifier) @reference.identifier
  (#set! reference_type read))

(for_statement
  left: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(for_statement
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(while_statement
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(if_statement
  condition: (identifier) @reference.identifier
  (#set! reference_type read))

(argument_list
  (identifier) @reference.identifier
  (#set! reference_type read))

(keyword_argument
  value: (identifier) @reference.identifier
  (#set! reference_type read))

(augmented_assignment
  left: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(augmented_assignment
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(subscript
  value: (identifier) @reference.identifier
  (#set! reference_type read))

(attribute
  object: (identifier) @reference.identifier
  (#set! reference_type read))

(call
  function: (identifier) @reference.identifier
  (#set! reference_type read))

((comment)* @output.comment
  .
  (function_definition) @output.function)

((comment)* @output.comment
  .
  (decorated_definition) @output.function)

((comment)* @output.comment
  .
  (decorated_definition) @output.method)

((comment)* @output.comment
  .
  (function_definition) @output.method)

(module) @scope

(class_definition
  body: (block
    (expression_statement
      (assignment
        left: (identifier) @local.definition.field)))) @scope

(class_definition
  body: (block
    (expression_statement
      (assignment
        left: (_
          (identifier) @local.definition.field))))) @scope

; Imports
(aliased_import
  alias: (identifier) @local.definition.import) @scope

(import_statement
  name: (dotted_name
    (identifier) @local.definition.import)) @scope

(import_from_statement
  name: (dotted_name
    (identifier) @local.definition.import)) @scope

(function_definition
  name: (identifier)) @scope

(class_definition
  name: (identifier)) @scope

(dictionary_comprehension) @scope

(list_comprehension) @scope

(set_comprehension) @scope
