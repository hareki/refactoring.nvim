(assignment_expression
  left: (identifier) @reference.identifier
  (#set! reference_type write))

(assignment_expression
  right: (identifier) @reference.identifier
  (#set! reference_type read))

(binary_expression
  (identifier) @reference.identifier
  (#set! reference_type read))

(update_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(augmented_assignment_expression
  (identifier) @reference.identifier
  (#set! reference_type write))

(arguments
  (identifier) @reference.identifier
  (#set! reference_type read))

(return_statement
  (identifier) @reference.identifier
  (#set! reference_type read))

(member_expression
  object: (identifier) @reference.identifier
  (#set! reference_type read))

(do_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(while_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(catch_clause
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(for_in_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(for_statement
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(method_definition
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(function_declaration
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(function_expression
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(program) @scope

(arrow_function
  body: (statement_block
    .
    (_) @scope.inside)) @scope

(if_statement
  consequence: (statement_block) @scope) @scope.outside

(if_statement
  alternative: (else_clause
    (statement_block) @scope)) @scope.outside

(class_declaration
  body: (class_body
    (_) @scope.inside)) @scope

; function a() {}
(program
  ((comment)* @output.comment
    (function_declaration) @output.function))

; const a = ()=>{}
(program
  ((comment)* @output.comment
    (lexical_declaration
      (variable_declarator
        (arrow_function))) @output.function))

; a = ()=>{}
(program
  ((comment)* @output.comment
    (expression_statement
      (assignment_expression
        (arrow_function))) @output.function))

(program
  (class_declaration
    (class_body
      ((comment)* @output.comment
        (method_definition) @output.function)))
  (#set! method true))
