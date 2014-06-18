role Perl6::Metamodel::Annotated {
     has %!annotations;
     method add_annotation( $obj, $key, $value ) {
         %!annotations || (%!annotations := {});
         return nqp::existskey(%!annotations, $key) ??  %!annotations{$key}
                                                    !! (%!annotations{$key} := $value)
     }
     method annotations( $obj ) { %!annotations }
}
