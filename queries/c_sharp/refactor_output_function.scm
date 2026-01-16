(compilation_unit
  _*
  (comment)* @output_function.comment
  .
  (global_statement
    (local_function_statement) @output_function))

(compilation_unit
  (class_declaration
    (declaration_list
      _*
      (comment)* @output_function.comment
      .
      [
        (method_declaration)
        (constructor_declaration)
      ] @output_function)))
