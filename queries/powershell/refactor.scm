(assignment_expression
  .
  (_) @variable.identifier
  value: (_) @variable.value) @variable.declaration

(script_parameter
  (variable) @reference.identifier
  (#set! reference_type write)
  (#set! declaration true))

; $foo = "foo"
(pipeline
  (logical_expression
    (bitwise_expression
      (comparison_expression
        (additive_expression
          (multiplicative_expression
            (format_expression
              (range_expression
                (array_literal_expression
                  (unary_expression
                    (variable) @reference.identifier)))))))))
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

; $foo.foo
(unary_expression
  (invokation_expression
    (variable) @reference.identifier)
  (#set! reference_type read))

(range_argument_expression
  (unary_expression
    (variable) @reference.identifier)
  (#set! reference_type read))

((comment)* @output.comment
  .
  (statement_list
    (function_statement) @output.function))

((comment)* @output.comment
  .
  (class_method_definition) @output.method)

(class_statement) @scope

(class_method_definition) @scope

(statement_block) @scope

(function_statement) @scope
