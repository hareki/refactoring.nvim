(if_statement
  (#set! text if)) @debug_path_segment

(while_statement
  (#set! text while)) @debug_path_segment

(do_statement
  (#set! text do)) @debug_path_segment

(for_statement
  (#set! text for)) @debug_path_segment

(function_definition
  declarator: (function_declarator
    declarator: (_) @_name)
  (#set! text @_name)) @debug_path_segment
