(source_file
  (function_declaration) @input_function)

(source_file
  (method_declaration
    receiver: (parameter_list
      (parameter_declaration
        name: (identifier) @_struct_var_name
        type: (pointer_type
          (type_identifier) @_struct_name)))) @input_function
  (#set! struct_name @_struct_name)
  (#set! struct_var_name @_struct_var_name))
