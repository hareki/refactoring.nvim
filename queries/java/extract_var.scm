(_
  (block
    .
    (_) @scope.inside)) @scope

; NOTE: records have parameters, and we are assuming that each variable
; declaration has a scope, so this most be their scope (even though they don't
; have a tradicional `block`)
(record_declaration) @scope

(class_declaration
  body: (class_body
    (_) @scope.inside)) @scope
