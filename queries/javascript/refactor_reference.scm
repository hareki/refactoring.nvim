;inherits: ecma

; let foo
(variable_declarator
  name: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

; let foo = 1
(variable_declarator
  name: (identifier) @reference.identifier
  value: (_) @_value
  (#infer-type! javascript @_value)
  (#set! reference_type write)
  (#set! declaration true))

(formal_parameters
  (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(field_definition
  (property_identifier) @reference.identifier
  (#set! declaration true)
  (#set! reference_type write))
