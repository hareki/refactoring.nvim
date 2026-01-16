(compilation_unit
  (global_statement
    (local_function_statement) @input_function))

(compilation_unit
  (class_declaration
    (declaration_list
      [
        (method_declaration)
        (constructor_declaration)
      ] @input_function))
  (#set! method true))
