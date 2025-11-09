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

(_
  (block
    .
    (_) @scope.inside)) @scope

(class_declaration
  body: (declaration_list
    (_) @scope.inside)) @scope

(compilation_unit
  _*
  (comment)* @output.comment
  .
  (global_statement
    (local_function_statement) @output.function))

(compilation_unit
  (class_declaration
    (declaration_list
      _*
      (comment)* @output.comment
      .
      [
        (method_declaration)
        (constructor_declaration)
      ] @output.function))
  (#set! method true))
