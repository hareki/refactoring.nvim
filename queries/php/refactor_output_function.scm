(program
  (class_declaration
    (declaration_list
      _*
      (comment)* @output_function.comment
      .
      (method_declaration) @output_function))
  (#set! method true))

(program
  _*
  (comment)* @output_function.comment
  .
  (function_definition) @output_function)
