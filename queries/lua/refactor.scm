; TODO: configure ts_query_ls for the repo once all the captures and predicates are stable-ish
; local foo = 'foo'
(variable_declaration
  (assignment_statement
    (variable_list
      .
      name: (identifier) @variable.identifier
      .
      ("," @variable.identifier_separator
        .
        name: (identifier) @variable.identifier)*)
    (expression_list
      .
      value: (_) @variable.value
      .
      ("," @variable.value_separator
        .
        value: (_) @variable.value)*))) @variable.declaration

; TODO: fix for multiple assignments
; foo.bar = 'bar'
(assignment_statement
  (variable_list
    name: (dot_index_expression) @variable.identifier)
  (expression_list
    value: (_) @variable.value)) @variable.declaration

; TODO: maybe join @reference and @variable queries in all languages(?
; foo = bar
(assignment_statement
  (variable_list
    name: (identifier) @reference.identifier
    (","
      name: (identifier) @reference.identifier)*)
  (expression_list
    value: (_) @_value
    (","
      value: (_) @_value)*)
  (#infer-type! lua @_value)
  (#set! reference_type write))

; foo.bar = 'bar'
(assignment_statement
  (variable_list
    name: [
      (dot_index_expression)
      (bracket_index_expression)
    ] @reference.identifier
    (","
      name: [
        (dot_index_expression)
        (bracket_index_expression)
      ] @reference.identifier)*)
  (expression_list
    value: (_) @_value
    (","
      value: (_) @_value)*)
  (#infer-type! lua @_value)
  (#set! reference_type write)
  (#set! declaration true))

; local foo = bar
(variable_declaration
  (assignment_statement
    (variable_list
      name: (identifier) @reference.identifier
      (","
        name: (identifier) @reference.identifier)*)
    (expression_list
      value: (_) @_value
      (","
        value: (_) @_value)*)
    (#infer-type! lua @_value)
    (#set! reference_type write)
    (#set! declaration true)))

; local foo
(variable_declaration
  (variable_list
    name: (identifier) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(bracket_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(dot_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(method_index_expression
  table: (identifier) @reference.identifier
  (#set! reference_type read))

(function_call
  (method_index_expression)
  (#set! reference_type read)) @reference.identifier

(arguments
  [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(parameters
  [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(function_call
  name: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(expression_list
  [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(binary_expression
  [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(for_numeric_clause
  name: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(for_numeric_clause
  end: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

(for_numeric_clause
  start: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

; repeat until/while/if
(_
  condition: [
    (identifier)
    (dot_index_expression)
    (bracket_index_expression)
    (function_call
      (method_index_expression))
  ] @reference.identifier
  (#set! reference_type read))

; local a = function() end
(chunk
  ((comment)* @output.comment
    (variable_declaration
      (assignment_statement
        (expression_list
          (function_definition)))) @output.function))

; a = function() end
(chunk
  ((comment)* @output.comment
    (assignment_statement
      (expression_list
        (function_definition))) @output.function))

; function a() end
(chunk
  ((comment)* @output.comment
    (function_declaration) @output.function))

; table.sort(function() end)
((function_definition
  body: (block) @scope.inside) @scope
  (#not-has-parent? @scope expression_list))

; foo = function() end
((assignment_statement
  (expression_list
    (function_definition
      body: (block) @scope.inside) @scope)) @scope.outside
  (#not-has-parent? @scope.outside variable_declaration))

; local foo = function() end
(variable_declaration
  (assignment_statement
    (expression_list
      (function_definition
        body: (block) @scope.inside) @scope))) @scope.outside

(function_declaration
  body: (block) @scope.inside) @scope

(for_statement
  body: (block) @scope.inside) @scope

(repeat_statement
  body: (block) @scope.inside) @scope

(while_statement
  body: (block) @scope.inside) @scope

(do_statement
  body: (block) @scope.inside) @scope

(chunk) @scope

(if_statement
  consequence: (block) @scope) @scope.outside

(if_statement
  alternative: (else_statement
    body: (block) @scope)) @scope.outside

((comment)* @function.comment
  (function_declaration
    parameters: (parameters
      (identifier) @function.arg
      (","
        (identifier) @function.arg)*)?
    body: (block) @function.body) @function)

((comment)* @function.comment
  (variable_declaration
    (assignment_statement
      (expression_list
        value: (function_definition
          parameters: (parameters
            (identifier) @function.arg
            (","
              (identifier) @function.arg)*)?
          body: (block) @function.body) @function))) @function.outside)

(return_statement
  (expression_list
    (identifier) @return.value
    (","
      (identifier) @return.value)*)?) @return

; b()
((function_call
  name: (identifier) @function_call.name
  arguments: (arguments
    .
    (_) @function_call.arg
    .
    (","
      (_) @function_call.arg)*)?) @function_call
  (#not-has-parent? @function_call expression_list))

; a = b()
((assignment_statement
  (variable_list
    name: (identifier) @function_call.return_value
    (","
      name: (identifier) @function_call.return_value)*)
  (expression_list
    value: (function_call
      name: (identifier) @function_call.name
      arguments: (arguments
        .
        (_) @function_call.arg
        .
        (","
          (_) @function_call.arg)*)?) @function_call)) @function_call.outside
  (#not-has-parent? @function_call.outside variable_declaration))

; local a = b()
(variable_declaration
  (assignment_statement
    (variable_list
      name: (identifier) @function_call.return_value
      (","
        name: (identifier) @function_call.return_value)*)
    (expression_list
      value: (function_call
        name: (identifier) @function_call.name
        arguments: (arguments
          .
          (_) @function_call.arg
          .
          (","
            (_) @function_call.arg)*)?) @function_call))) @function_call.outside

[
  (statement)
  (return_statement)
] @statement

(comment) @comment
