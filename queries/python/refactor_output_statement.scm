; _simple_statement
[
  (future_import_statement)
  (import_statement)
  (import_from_statement)
  (print_statement)
  (assert_statement)
  (expression_statement)
  (return_statement)
  (delete_statement)
  (raise_statement)
  (pass_statement)
  (break_statement)
  (continue_statement)
  (global_statement)
  (nonlocal_statement)
  (exec_statement)
  (type_alias_statement)
] @output_statement

; _compund_statement
[
  (if_statement)
  (for_statement)
  (while_statement)
  (try_statement)
  (with_statement)
  (function_definition)
  (class_definition)
  (decorated_definition)
  (match_statement)
] @output_statement
