[
  (empty_statement)
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
  body: (_) @output_statement.inside
  (#set! inside_only)) @output_statement

(block
  (function_call) @output_statement)

(chunk
  (function_call) @output_statement)

((assignment_statement) @output_statement
  (#not-has-parent? @output_statement variable_declaration))
