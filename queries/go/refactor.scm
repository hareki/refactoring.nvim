(short_var_declaration
  left: (expression_list
    (identifier) @variable.identifier)
  right: (expression_list
    (_) @variable.value)) @variable.declaration

(var_declaration
  (var_spec
    name: (identifier) @variable.identifier
    value: (_) @variable.value)) @variable.declaration

(var_spec
  (identifier) @reference.identifier)

(expression_list
  (identifier) @reference.identifier)

(binary_expression
  (identifier) @reference.identifier)

(inc_statement
  (identifier) @reference.identifier)

(argument_list
  (identifier) @reference.identifier)

(selector_expression
  operand: (identifier) @reference.identifier)

((comment)* @output.comment
  (function_declaration) @output.function)

((comment)* @output.comment
  (method_declaration
    receiver: (parameter_list
      (parameter_declaration
        name: (identifier) @output.struct_var_name
        type: (pointer_type
          (type_identifier) @output.struct_name)))) @output.function)

(func_literal) @scope

(source_file) @scope

(function_declaration) @scope

(if_statement) @scope

(block) @scope

(expression_switch_statement) @scope

(for_statement) @scope

(method_declaration) @scope
