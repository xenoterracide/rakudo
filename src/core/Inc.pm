{
    my @INC;
    my %CUSTOM_LIB;

    my @all_paths;
    sub make-cur($class, $path) {
        @all_paths.push: $path;
        if $class eq 'CompUnitRepo::Local::File' {
            CompUnitRepo::Local::File.new($path);
        }
        elsif $class eq 'CompUnitRepo::Local::Installation' {
            CompUnitRepo::Local::Installation.new($path);
        }
        else {
            my $name = 'lib/' ~ $class.split('::').join('/') ~ '.pm';
            for @all_paths -> $previous_path {
                if "$previous_path/$name".IO.e {
                    require "$previous_path/$name";
                    return ::($class).new($path);
                }
            }
        }
    }

    # Add CompUnitRepos to @*INC and also to %*CUSTOM_LIB if they have a name.
    sub add-curs($line, $sep = ',') {
        my %options;
        if $line && $line ~~ /^ [ $<class>=[ <.ident>+ % '::' ] [ ':' $<n>=\w+ <[<([]> $<v>=<[\w-]>+ <[>)\]]> { %options{$<n>} = $<v> } ]* '=' ]? $<path>=.+ $/ {
            my $class = $<class> ?? ~$<class> !! 'CompUnitRepo::Local::File';
            my @paths = $<path>.split($sep);
            for @paths -> $path {
                if make-cur($class, $path) -> $cur {
                    %CUSTOM_LIB{~%options<name>} = $cur if %options<name>;
                    @INC.push: $cur
                }
            }
        }
    }

    my $I := nqp::atkey(nqp::atkey(%*COMPILING, '%?OPTIONS'), 'I');
    if nqp::defined($I) {
        if nqp::islist($I) {
            my Mu $iter := nqp::iterator($I);
            add-curs(nqp::p6box_s(nqp::shift($iter))) while $iter;
        }
        else {
            add-curs(nqp::p6box_s($I));
        }
    }

    my $path-sep := $*DISTRO.path-sep;
    add-curs(%*ENV<RAKUDOLIB>, $path-sep) if %*ENV<RAKUDOLIB>;
    add-curs(%*ENV<PERL6LIB>, $path-sep)  if %*ENV<PERL6LIB>;

#?if jvm
    for nqp::jvmclasspaths() -> $path {
        add-curs($path, $path-sep) if nqp::stat($path, nqp::const::STAT_ISDIR);
    }
#?endif

    my $prefix := $*VM.prefix ~ '/languages/perl6';
    if "$prefix/share/libraries.json".IO.e {
        my $config = "$prefix/share/libraries.json".IO.e ?? from-json( slurp "$prefix/share/libraries.json" ) !! [];

        for $config.list -> @group {
            my @cur_group;
            for @group>>.kv -> $class, $props {
                for $props.list -> $prop {
                    if $prop ~~ Associative {
                        for $prop.value.flat -> $path {
                            if make-cur($class, $path) -> $cur {
                                @cur_group.push: $cur;
                                %CUSTOM_LIB{$prop.key} = $cur;
                            }
                        }
                    }
                    else {
                        for $prop.flat -> $path {
                            if make-cur($class, $path) -> $cur {
                                @cur_group.push: $cur;
                            }
                        }
                    }
                }
            }
            @INC.push: +@cur_group > 1 ?? [@cur_group] !! @cur_group
        }
    }
    # There is no config file, so pick sane defaults.
    else {
        # XXX Various issues with this stuff on JVM
        my Mu $compiler := nqp::getcurhllsym('$COMPILER_CONFIG');  # TEMPORARY
        my @cur_inst;
        try {
            my $home := %*ENV<HOME> // %*ENV<HOMEDRIVE> ~ %*ENV<HOMEPATH>;
            my $ver  := nqp::p6box_s(nqp::atkey($compiler, 'version'));
            if CompUnitRepo::Local::File.new("$home/.perl6/$ver/lib") -> $cur {
                @INC.push: $cur;
            }
            if CompUnitRepo::Local::Installation.new("$home/.perl6/$ver") -> $cur {
                @cur_inst.push: %CUSTOM_LIB<home> = $cur;
            }
        }
        if CompUnitRepo::Local::File.new("$prefix/lib") -> $cur {
            @INC.push: $cur;
        }
        if CompUnitRepo::Local::File.new("$prefix/vendor/lib") -> $cur {
            @INC.push: $cur;
        }
        if CompUnitRepo::Local::File.new("$prefix/site/lib") -> $cur {
            @INC.push: $cur;
        }
        if CompUnitRepo::Local::Installation.new($prefix) -> $cur {
            @cur_inst.push: %CUSTOM_LIB<perl> = $cur;
        }
        if CompUnitRepo::Local::Installation.new("$prefix/vendor") -> $cur {
            @cur_inst.push: %CUSTOM_LIB<vendor> = $cur;
        }
        if CompUnitRepo::Local::Installation.new("$prefix/site") -> $cur {
            @cur_inst.push: %CUSTOM_LIB<site> = $cur;
        }
        @INC.push([@cur_inst]) if @cur_inst;
    }

    PROCESS::<@INC>        := @INC;
    PROCESS::<%CUSTOM_LIB> := %CUSTOM_LIB;

    nqp::bindhllsym('perl6', 'ModuleLoader', CompUnitRepo);
}

# vim: ft=perl6 expandtab sw=4
