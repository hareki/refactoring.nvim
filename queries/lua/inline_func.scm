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
