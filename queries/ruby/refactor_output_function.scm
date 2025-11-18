(program
  (class
    (body_statement
      _*
      (comment)* @output_function.comment
      .
      (singleton_method) @output_function))
  (#set! method true)
  (#set! singleton true))

(program
  (class
    (body_statement
      _*
      (comment)* @output_function.comment
      .
      (method) @output_function))
  (#set! method true))

(program
  _*
  (comment)* @output_function.comment
  .
  (method) @output_function)

(program
  _*
  (comment)* @output_function.comment
  .
  (singleton_method) @output_function
  (#set! singleton true))
