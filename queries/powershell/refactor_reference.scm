(script_parameter
  (variable) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

; $foo = "foo"
(pipeline
  (assignment_expression
    (left_assignment_expression
      (logical_expression
        (bitwise_expression
          (comparison_expression
            (additive_expression
              (multiplicative_expression
                (format_expression
                  (range_expression
                    (array_literal_expression
                      (unary_expression
                        (variable) @reference.identifier)))))))))))
  (#set! reference_type read))

; $bar = $foo
(assignment_expression
  (left_assignment_expression
    (logical_expression
      (bitwise_expression
        (comparison_expression
          (additive_expression
            (multiplicative_expression
              (format_expression
                (range_expression
                  (array_literal_expression
                    (unary_expression
                      (variable) @reference.identifier))))))))))
  (#set! reference_type write)
  (#set! declaration true))

; $foo -lt 5
(comparison_expression
  (comparison_expression
    (additive_expression
      (multiplicative_expression
        (format_expression
          (range_expression
            (array_literal_expression
              (unary_expression
                (variable) @reference.identifier)))))))
  (#set! reference_type read))

(additive_expression
  (additive_expression
    (multiplicative_expression
      (format_expression
        (range_expression
          (array_literal_expression
            (unary_expression
              (variable) @reference.identifier))))))
  (#set! reference_type read))

; $foo++ $foo--
(unary_expression
  [
    (post_increment_expression
      (variable) @reference.identifier)
    (post_decrement_expression
      (variable) @reference.identifier)
  ]
  (#set! reference_type write)
  (#set! declaration true))

; ++$foo
(pre_increment_expression
  (unary_expression
    (variable) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

; --$foo
(pre_decrement_expression
  (unary_expression
    (variable) @reference.identifier)
  (#set! reference_type write)
  (#set! declaration true))

; $foo[0]
(unary_expression
  (element_access
    (variable) @reference.identifier)
  (#set! reference_type read))

; write-host $foo
(array_literal_expression
  (unary_expression
    (variable) @reference.identifier))

; $foo.foo
(unary_expression
  (member_access
    (variable) @reference.identifier)
  (#set! reference_type read))

; $foo.foo()
(unary_expression
  (invokation_expression
    (variable) @reference.identifier)
  (#set! reference_type read)
  (#set! function_call_identifier true))

(range_argument_expression
  (unary_expression
    (variable) @reference.identifier)
  (#set! reference_type read))

(function_statement
  (function_name) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(class_method_definition
  (simple_name) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

(expandable_string_literal
  (variable) @reference.identifier
  (#set! reference_type read))

(expandable_here_string_literal
  (variable) @reference.identifier
  (#set! reference_type read))

; -not $foo
(expression_with_unary_operator
  (unary_expression
    (variable) @reference.identifier)
  (#set! reference_type read))
