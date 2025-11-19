(script_file) @scope.inside @scope @scope.outside

(function_definition
  (function_declaration
    parameters: (_) @scope)
  (body) @scope.inside @scope) @scope.outside
