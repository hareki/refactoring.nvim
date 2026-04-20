;inherits: ecma

; let foo: number = 1 / let foo:number
(variable_declarator
  name: (identifier) @reference.identifier
  type: (type_annotation
    (_) @_type)
  (#set-type! typescript @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration))

; let foo = 1
(variable_declarator
  name: (identifier) @reference.identifier
  value: (_) @_value
  (#infer-type! typescript @_value)
  (#set! reference_type write)
  (#set! declaration))

; let foo
(variable_declarator
  name: (identifier) @reference.identifier
  (#set! reference_type write)
  (#set! declaration))

(required_parameter
  pattern: (identifier) @reference.identifier
  type: (type_annotation
    (_) @_type)?
  (#set-type! typescript @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration))

(optional_parameter
  pattern: (identifier) @reference.identifier
  type: (type_annotation
    (_) @_type)?
  (#set-type! typescript @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration))

(required_parameter
  pattern: (object_pattern
    (shorthand_property_identifier_pattern) @reference.identifier)
  type: (type_annotation
    (_) @_type)?
  (#set-type! typescript @_type @reference.identifier)
  (#set! reference_type write)
  (#set! declaration))
