(_statement) @output_statement

(function_declaration
  body: (block
    (statement_list) @output_statement.inside)) @output_statement

(method_declaration
  body: (block
    (statement_list) @output_statement.inside)) @output_statement
