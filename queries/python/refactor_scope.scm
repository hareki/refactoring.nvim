(module) @scope.inside @scope

(class_definition
  body: (_) @scope.inside @scope)

(function_definition
  parameters: (_) @scope
  body: (block) @scope.inside @scope)

(dictionary_comprehension) @scope.inside @scope

(list_comprehension) @scope.inside @scope

(set_comprehension) @scope.inside @scope
