(program
  _*
  (comment)* @output_function.comment
  .
  (statement_list
    (function_statement) @output_function))

(program
  (statement_list
    (class_statement
      _*
      (comment)* @output_function.comment
      .
      (class_method_definition) @output_function))
  (#set! method true))
