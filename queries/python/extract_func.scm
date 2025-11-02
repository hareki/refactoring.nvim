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

(module) @scope

(class_definition) @scope

(function_definition
  body: (block) @scope.inside) @scope

(dictionary_comprehension) @scope

(list_comprehension) @scope

(set_comprehension) @scope

(module
  ((comment)* @output.comment
    [
      (function_definition)
      (decorated_definition)
    ] @output.function))

(module
  (class_definition
    (block
      ((comment)* @output.comment
        [
          (function_definition)
          (decorated_definition)
        ] @output.function)))
  (#set! method true))
