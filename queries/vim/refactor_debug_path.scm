(if_statement
  (#set! text if)) @debug_path_segment

(for_loop
  (#set! text for)) @debug_path_segment

(while_loop
  (#set! text while)) @debug_path_segment

(try_statement
  (#set! text try)) @debug_path_segment

(function_definition
  (function_declaration
    name: (_) @_name)
  (#set! text @_name)) @debug_path_segment
