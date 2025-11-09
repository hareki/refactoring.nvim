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

; _simple_statement
[
  (future_import_statement)
  (import_statement)
  (import_from_statement)
  (print_statement)
  (assert_statement)
  (expression_statement)
  (return_statement)
  (delete_statement)
  (raise_statement)
  (pass_statement)
  (break_statement)
  (continue_statement)
  (global_statement)
  (nonlocal_statement)
  (exec_statement)
  (type_alias_statement)
] @output_statement

; _compund_statement
[
  (if_statement)
  (for_statement)
  (while_statement)
  (try_statement)
  (with_statement)
  (function_definition)
  (class_definition)
  (decorated_definition)
  (match_statement)
] @output_statement

(module) @scope

(class_definition) @scope

(function_definition
  body: (block) @scope.inside) @scope

(dictionary_comprehension) @scope

(list_comprehension) @scope

(set_comprehension) @scope
