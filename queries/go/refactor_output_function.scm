(source_file
  _*
  (comment)* @output_function.comment
  .
  (function_declaration) @output_function)

(source_file
  _*
  (comment)* @output_function.comment
  .
  (method_declaration
    receiver: (parameter_list
      (parameter_declaration
        name: (identifier) @_struct_var_name
        type: (pointer_type
          (type_identifier) @_struct_name)))) @output_function
  (#set! struct_name @_struct_name)
  (#set! struct_var_name @_struct_var_name))
