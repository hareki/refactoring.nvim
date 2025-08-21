(assignment
  left: [
    (identifier)
    (attribute)
  ] @variable.identifier
  right: (_) @variable.value) @variable.declaration

(assignment
  left: [
    (pattern_list
      (identifier) @variable.identifier)
    (tuple_pattern
      (identifier) @variable.identifier)
  ]
  right: (expression_list
    (_) @variable.value)) @variable.declaration

(assignment
  (identifier) @reference.identifier)

(binary_operator
  (identifier) @reference.identifier)

(for_statement
  left: (identifier) @reference.identifier)

(while_statement
  condition: (identifier) @reference.identifier)

(if_statement
  condition: (identifier) @reference.identifier)

(argument_list
  (identifier) @reference.identifier)

(keyword_argument
  value: (identifier) @reference.identifier)

(augmented_assignment
  (identifier) @reference.identifier)

(return_statement
  (identifier) @reference.identifier)

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
