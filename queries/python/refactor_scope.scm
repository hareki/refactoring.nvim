(module) @scope.inside @scope @scope.outside

(class_definition
  body: (_) @scope.inside @scope) @scope.outside

(function_definition
  parameters: (_) @scope
  body: (block) @scope.inside @scope) @scope.outside

(dictionary_comprehension) @scope.inside @scope @scope.outside

(list_comprehension) @scope.inside @scope @scope.outside

(set_comprehension) @scope.inside @scope @scope.outside
