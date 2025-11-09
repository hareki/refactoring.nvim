(if_statement
  (#set! text if)) @debug_path

(repeat_statement
  (#set! text repeat)) @debug_path

(do_statement
  (#set! text do)) @debug_path

(for_statement
  (#set! text for)) @debug_path

(while_statement
  (#set! text while)) @debug_path

(function_declaration
  name: (_) @_name
  (#set! text @_name)) @debug_path

(assignment_statement
  (variable_list
    name: (_) @_name
    (","
      name: (_) @_name)*)
  (expression_list
    value: (function_definition) @debug_path
    (","
      value: (function_definition) @debug_path)*)
  (#set! text @_name))

((function_definition) @debug_path
  (#not-has-parent? @debug_path expression_list)
  (#set! text "(anon)"))

[
  (empty_statement)
  (assignment_statement)
  (function_call)
  (label_statement)
  (break_statement)
  (goto_statement)
  (return_statement)
  (variable_declaration)
] @output_statement

(do_statement
  body: (_) @output_statement.inside) @output_statement

(while_statement
  body: (_) @output_statement.inside) @output_statement

(repeat_statement
  body: (_) @output_statement.inside) @output_statement

(if_statement
  consequence: (_) @output_statement.inside) @output_statement

(elseif_statement
  consequence: (_) @output_statement.inside) @output_statement

(else_statement
  body: (_) @output_statement.inside) @output_statement

(for_statement
  body: (_) @output_statement.inside) @output_statement

(function_declaration
  body: (_) @output_statement.inside) @output_statement

(function_definition
  body: (_) @output_statement.inside) @output_statement
