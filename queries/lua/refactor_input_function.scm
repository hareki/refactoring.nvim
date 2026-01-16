; local a = function() end
(chunk
  (variable_declaration
    (assignment_statement
      (expression_list
        (function_definition)))) @input_function)

; a = function() end
(chunk
  (assignment_statement
    (expression_list
      (function_definition))) @input_function)

; function a() end
(chunk
  (function_declaration) @input_function)
