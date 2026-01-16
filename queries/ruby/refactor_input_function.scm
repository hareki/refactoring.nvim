(program
  (class
    (body_statement
      (singleton_method) @input_function))
  (#set! method true)
  (#set! singleton true))

(program
  (class
    (body_statement
      (method) @input_function))
  (#set! method true))

(program
  (method) @input_function)

(program
  (singleton_method) @input_function
  (#set! singleton true))
