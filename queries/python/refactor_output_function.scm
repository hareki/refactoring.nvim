(module
  _*
  (comment)* @output_function.comment
  .
  [
    (function_definition)
    (decorated_definition)
  ] @output_function)

(module
  (class_definition
    (block
      _*
      (comment)* @output_function.comment
      .
      [
        (function_definition)
        (decorated_definition)
      ] @output_function))
  (#set! method true))
