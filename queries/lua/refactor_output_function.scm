; local a = function() end
(chunk
  _*
  (comment)* @output_function.comment
  .
  (variable_declaration
    (assignment_statement
      (expression_list
        (function_definition)))) @output_function)

; a = function() end
(chunk
  _*
  (comment)* @output_function.comment
  (assignment_statement
    (expression_list
      (function_definition))) @output_function)

; function a() end
(chunk
  _*
  (comment)* @output_function.comment
  .
  (function_declaration) @output_function)
