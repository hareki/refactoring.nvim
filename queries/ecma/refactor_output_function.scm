; function a() {}
(program
  _*
  (comment)* @output_function.comment
  .
  (function_declaration) @output_function)

; const a = ()=>{}
(program
  _*
  (comment)* @output_function.comment
  .
  (lexical_declaration
    (variable_declarator
      (arrow_function))) @output_function)

; a = ()=>{}
(program
  _*
  (comment)* @output_function.comment
  .
  (expression_statement
    (assignment_expression
      (arrow_function))) @output_function)

(program
  (class_declaration
    (class_body
      _*
      (comment)* @output_function.comment
      .
      (method_definition) @output_function)))
