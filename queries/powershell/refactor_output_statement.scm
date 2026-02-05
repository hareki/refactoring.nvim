(statement_list
  [
    (function_statement)
    (class_statement)
    (enum_statement)
    (flow_control_statement)
    (trap_statement)
    (try_statement)
    (data_statement)
    (inlinescript_statement)
    (parallel_statement)
    (sequence_statement)
    (pipeline)
    (empty_statement)
    (switch_statement)
  ] @output_statement)

(foreach_statement
  (statement_block
    (statement_list) @output_statement.inside)) @output_statement

(if_statement
  (statement_block
    (statement_list) @output_statement.inside)) @output_statement

(do_statement
  (statement_block
    (statement_list) @output_statement.inside)) @output_statement

(while_statement
  (statement_block
    (statement_list) @output_statement.inside)) @output_statement

(for_statement
  (statement_block
    (statement_list) @output_statement.inside)) @output_statement
