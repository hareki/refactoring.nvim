; table.sort(function() end)
((function_definition
  body: (block) @scope.inside) @scope
  (#not-has-parent? @scope expression_list))

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
  body: (block) @scope.inside) @scope

(for_statement
  body: (block) @scope.inside) @scope

(repeat_statement
  body: (block) @scope.inside) @scope

(while_statement
  body: (block) @scope.inside) @scope

(do_statement
  body: (block) @scope.inside) @scope

(chunk) @scope

(if_statement
  consequence: (block) @scope) @scope.outside

(if_statement
  alternative: (else_statement
    body: (block) @scope)) @scope.outside
