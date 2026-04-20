(if_statement
  (#set! text if)) @debug_path_segment

(do_statement
  (#set! text do)) @debug_path_segment

(for_statement
  (#set! text for)) @debug_path_segment

(while_statement
  (#set! text while)) @debug_path_segment

(function_statement
  (function_name) @_name
  (#set! text @_name)) @debug_path_segment

(class_method_definition
  (simple_name) @_name
  (#set! text @_name)) @debug_path_segment

(script_block_expression
  (#set! text "(anon)")) @debug_path_segment
