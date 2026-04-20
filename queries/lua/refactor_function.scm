((comment)* @function.comment
  .
  (function_declaration
    parameters: (parameters
      (identifier) @function.arg
      (","
        (identifier) @function.arg)*)?
    body: (block) @function.body) @function)

((comment)* @function.comment
  .
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
    (_) @return.value
    (","
      (_) @return.value)*)?) @return
