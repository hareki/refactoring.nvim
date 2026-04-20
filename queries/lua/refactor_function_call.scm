; b()
((function_call
  name: (_) @function_call.name
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
    name: (_) @function_call.return_value
    (","
      name: (_) @function_call.return_value)*)
  (expression_list
    value: (function_call
      name: (_) @function_call.name
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
      name: (_) @function_call.return_value
      (","
        name: (_) @function_call.return_value)*)
    (expression_list
      value: (function_call
        name: (_) @function_call.name
        arguments: (arguments
          .
          (_) @function_call.arg
          .
          (","
            (_) @function_call.arg)*)?) @function_call))) @function_call.outside
