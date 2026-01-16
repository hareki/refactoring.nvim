; function a() {}
(program
  (function_declaration) @input_function)

; const a = ()=>{}
(program
  (lexical_declaration
    (variable_declarator
      (arrow_function))) @input_function)

; a = ()=>{}
(program
  (expression_statement
    (assignment_expression
      (arrow_function))) @input_function)

(program
  (class_declaration
    (class_body
      (method_definition) @input_function))
  (#set! method true))
