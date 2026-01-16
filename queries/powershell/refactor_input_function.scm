(program
  (statement_list
    (function_statement) @input_function))

(program
  (statement_list
    (class_statement
      (class_method_definition) @input_function))
  (#set! method true))
