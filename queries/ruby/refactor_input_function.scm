(program
  (class
    (body_statement
      (singleton_method) @input_function))
  (#set! method)
  (#set! singleton))

(program
  (class
    (body_statement
      (method) @input_function))
  (#set! method))

(program
  (method) @input_function)

(program
  (singleton_method) @input_function
  (#set! singleton))
