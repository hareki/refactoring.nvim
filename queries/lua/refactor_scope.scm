; table.sort(function() end)
(function_call
  (arguments
    (function_definition
      body: (block) @scope.inside) @scope)) @scope.outside

(while_statement
  (function_definition
    body: (block) @scope.inside) @scope) @scope.outside

(repeat_statement
  (function_definition
    body: (block) @scope.inside) @scope) @scope.outside

(if_statement
  (function_definition
    body: (block) @scope.inside) @scope) @scope.outside

; foo = function() end
((assignment_statement
  (expression_list
    (function_definition
      body: (block) @scope.inside) @scope)) @scope.outside
  (#not-has-parent? @scope.outside variable_declaration))

; local foo = function() end
(variable_declaration
  (assignment_statement
    (expression_list
      (function_definition
        body: (block) @scope.inside) @scope))) @scope.outside

(function_declaration
  parameters: (parameters) @scope
  body: (block) @scope @scope.inside) @scope.outside

(for_statement
  body: (block) @scope.inside) @scope @scope.outside

(repeat_statement
  body: (block) @scope.inside) @scope @scope.outside

(while_statement
  body: (block) @scope.inside) @scope @scope.outside

(do_statement
  body: (block) @scope.inside) @scope @scope.outside

(chunk) @scope @scope.inside @scope.outside

(if_statement
  consequence: (block) @scope @scope.inside) @scope.outside

(if_statement
  alternative: (else_statement
    body: (block) @scope @scope.inside)) @scope.outside
