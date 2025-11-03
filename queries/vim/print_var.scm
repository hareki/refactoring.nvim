(parameters
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! declaration true))

(unlet_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(let_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(let_statement
  (list_assignment
    [
      (identifier)
      (scoped_identifier)
    ] @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

(binary_operation
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(unary_operation
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(if_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(return_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(call_expression
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(field_expression
  value: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(argument
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(dictionnary_entry
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(index_expression
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(for_loop
  variable: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(for_loop
  iter: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(while_loop
  condition: [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

(echo_statement
  [
    (identifier)
    (scoped_identifier)
  ] @reference.identifier
  (#set! reference_type read))

[
  (function_definition)
  (let_statement)
  (unlet_statement)
  (const_statement)
  (set_statement)
  (setlocal_statement)
  (return_statement)
  (normal_statement)
  (while_loop)
  (for_loop)
  (if_statement)
  (lua_statement)
  (range_statement)
  (ruby_statement)
  (python_statement)
  (perl_statement)
  (call_statement)
  (execute_statement)
  (echo_statement)
  (echon_statement)
  (echohl_statement)
  (echomsg_statement)
  (echoerr_statement)
  (try_statement)
  (throw_statement)
  (autocmd_statement)
  (silent_statement)
  (vertical_statement)
  (belowright_statement)
  (aboveleft_statement)
  (topleft_statement)
  (botright_statement)
  (register_statement)
  (map_statement)
  (augroup_statement)
  (bang_filter_statement)
  (highlight_statement)
  (syntax_statement)
  (setfiletype_statement)
  (options_statement)
  (startinsert_statement)
  (stopinsert_statement)
  (scriptencoding_statement)
  (source_statement)
  (global_statement)
  (colorscheme_statement)
  (command_statement)
  (comclear_statement)
  (delcommand_statement)
  (filetype_statement)
  (runtime_statement)
  (wincmd_statement)
  (sign_statement)
  (break_statement)
  (continue_statement)
  (cnext_statement)
  (cprevious_statement)
  (unknown_builtin_statement)
  (edit_statement)
  (enew_statement)
  (find_statement)
  (ex_statement)
  (visual_statement)
  (view_statement)
  (eval_statement)
  (substitute_statement)
  (user_command)
] @statement

(script_file) @scope

(function_definition
  (body) @scope.inside) @scope
