my class X::Bind { ... }
my class X::Caller::NotDynamic { ... }

my class Label {
    has Str $!name;
    has Mu $!match;
    method new(:$name, Mu :$match) {
        # XXX register in &?BLOCK.labels
        my $obj := nqp::create(self);
        nqp::bindattr($obj, Label, '$!name',  $name);
        nqp::bindattr($obj, Label, '$!match', $match);
        $obj
    }
    method name() {
        $!name
    }
    method match() {
        $!match
    }
    # XXX method leave(@args)
    # XXX method goto
    method gist() {
        my $file  = nqp::getlexdyn('$?FILES');
        $file     = nqp::box_s((nqp::isnull($file) ?? '<unknown file>' !! $file), Str);
        my $line  = HLL::Compiler.lineof($!match.orig, $!match.from);
        my $left  = nqp::substr($!match.orig, 0, $!match.from);
        my $right = nqp::substr($!match.orig, $!match.to, $!match.orig.chars - $!match.to);
        $left     = $left.match(/   \N ** 0..20 $/).Str.trim-leading;
        $right    = $right.match(/^ \N ** 0..20  /).Str.trim-trailing;

        my $color = %*ENV<RAKUDO_ERROR_COLOR> // $*OS ne 'MSWin32';
        my ($red, $green, $yellow, $clear) = $color
            ?? ("\e[31m", "\e[32m", "\e[33m", "\e[0m")
            !! ("", "", "", "");
        my $eject = $*OS eq 'MSWin32' ?? "<HERE>" !! "\x[23CF]";

        "Label<$!name>(at $file:$line, '$green$left$yellow$eject$red$!name:$green$right$clear')"
    }
    method next() {
        my Mu $ex := nqp::newexception();
        nqp::setpayload($ex, self);
        nqp::setextype($ex, nqp::const::CONTROL_NEXT + nqp::const::CONTROL_LABELED);
        nqp::throw($ex);
    }
    method redo() {
        my Mu $ex := nqp::newexception();
        nqp::setpayload($ex, self);
        nqp::setextype($ex, nqp::const::CONTROL_REDO + nqp::const::CONTROL_LABELED);
        nqp::throw($ex);
    }
    method last() {
        my Mu $ex := nqp::newexception();
        nqp::setpayload($ex, self);
        nqp::setextype($ex, nqp::const::CONTROL_LAST + nqp::const::CONTROL_LABELED);
        nqp::throw($ex);
    }
}

my class PseudoStash is EnumMap {
    has Mu $!ctx;
    has int $!mode;
    
    # Lookup modes.
    my int constant PICK_CHAIN_BY_NAME = 0;
    my int constant STATIC_CHAIN       = 1;
    my int constant DYNAMIC_CHAIN      = 2;
    my int constant PRECISE_SCOPE      = 4;
    my int constant REQUIRE_DYNAMIC    = 8;

    method new() {
        my $obj := nqp::create(self);
        my $ctx := nqp::ctxcaller(nqp::ctx());
        nqp::bindattr($obj, PseudoStash, '$!ctx', $ctx);
        nqp::bindattr($obj, EnumMap, '$!storage', nqp::ctxlexpad($ctx));
        $obj
    }
    
    my %pseudoers =
        'MY' => sub ($cur) {
            my $stash := nqp::clone($cur);
            nqp::bindattr_i($stash, PseudoStash, '$!mode', PRECISE_SCOPE);
            nqp::setwho(
                Metamodel::ModuleHOW.new_type(:name('MY')),
                $stash);
        },
        'CORE' => sub ($cur) {
            my Mu $ctx := nqp::getattr(nqp::decont($cur), PseudoStash, '$!ctx');
            until nqp::existskey(nqp::ctxlexpad($ctx), '!CORE_MARKER') {
                $ctx := nqp::ctxouterskipthunks($ctx);
            }
            my $stash := nqp::create(PseudoStash);
            nqp::bindattr($stash, EnumMap, '$!storage', nqp::ctxlexpad($ctx));
            nqp::bindattr($stash, PseudoStash, '$!ctx', $ctx);
            nqp::bindattr_i($stash, PseudoStash, '$!mode', PRECISE_SCOPE);
            nqp::setwho(
                Metamodel::ModuleHOW.new_type(:name('CORE')),
                $stash);
        },
        'CALLER' => sub ($cur) {
            my Mu $ctx := nqp::ctxcallerskipthunks(
                nqp::getattr(nqp::decont($cur), PseudoStash, '$!ctx'));
            my $stash := nqp::create(PseudoStash);
            nqp::bindattr($stash, EnumMap, '$!storage', nqp::ctxlexpad($ctx));
            nqp::bindattr($stash, PseudoStash, '$!ctx', $ctx);
            nqp::bindattr_i($stash, PseudoStash, '$!mode', PRECISE_SCOPE +| REQUIRE_DYNAMIC);
            nqp::setwho(
                Metamodel::ModuleHOW.new_type(:name('CALLER')),
                $stash);
        },
        'OUTER' => sub ($cur) {
            my Mu $ctx := nqp::ctxouterskipthunks(
                nqp::getattr(nqp::decont($cur), PseudoStash, '$!ctx'));
            my $stash := nqp::create(PseudoStash);
            nqp::bindattr($stash, EnumMap, '$!storage', nqp::ctxlexpad($ctx));
            nqp::bindattr($stash, PseudoStash, '$!ctx', $ctx);
            nqp::bindattr_i($stash, PseudoStash, '$!mode', PRECISE_SCOPE);
            nqp::setwho(
                Metamodel::ModuleHOW.new_type(:name('OUTER')),
                $stash);
        },
        'DYNAMIC' => sub ($cur) {
            my $stash := nqp::clone($cur);
            nqp::bindattr_i($stash, PseudoStash, '$!mode', DYNAMIC_CHAIN);
            nqp::setwho(
                Metamodel::ModuleHOW.new_type(:name('DYNAMIC')),
                $stash);
        },
        'UNIT' => sub ($cur) {
            my Mu $ctx := nqp::getattr(nqp::decont($cur), PseudoStash, '$!ctx');
            until nqp::existskey(nqp::ctxlexpad($ctx), '!UNIT_MARKER') {
                $ctx := nqp::ctxouterskipthunks($ctx);
            }
            my $stash := nqp::create(PseudoStash);
            nqp::bindattr($stash, EnumMap, '$!storage',nqp::ctxlexpad($ctx));
            nqp::bindattr($stash, PseudoStash, '$!ctx', $ctx);
            nqp::bindattr_i($stash, PseudoStash, '$!mode', PRECISE_SCOPE);
            nqp::setwho(
                Metamodel::ModuleHOW.new_type(:name('UNIT')),
                $stash);
        },
        'SETTING' => sub ($cur) {
            # Same as UNIT, but go a little further out (two steps, for
            # internals reasons).
            my Mu $ctx := nqp::getattr(nqp::decont($cur), PseudoStash, '$!ctx');
            until nqp::existskey(nqp::ctxlexpad($ctx), '!UNIT_MARKER') {
                $ctx := nqp::ctxouterskipthunks($ctx);
            }
            $ctx := nqp::ctxouter(nqp::ctxouter($ctx));
            my $stash := nqp::create(PseudoStash);
            nqp::bindattr($stash, EnumMap, '$!storage', nqp::ctxlexpad($ctx));
            nqp::bindattr($stash, PseudoStash, '$!ctx', $ctx);
            nqp::bindattr_i($stash, PseudoStash, '$!mode', PRECISE_SCOPE);
            nqp::setwho(
                Metamodel::ModuleHOW.new_type(:name('UNIT')),
                $stash);
        },
        'OUR' => sub ($cur) {
            nqp::getlexrel(
                nqp::getattr(nqp::decont($cur), PseudoStash, '$!ctx'),
                '$?PACKAGE')
        };
    
    method at_key($key is copy) is rw {
        $key = $key.Str;
        my Mu $nkey := nqp::unbox_s($key);
        if %pseudoers.exists_key($key) {
            %pseudoers{$key}(self)
        }
        elsif nqp::bitand_i($!mode, PRECISE_SCOPE) {
            my Mu $store := nqp::getattr(self, EnumMap, '$!storage');
            my Mu $res := nqp::existskey($store, $nkey) ??
                            nqp::atkey($store, $nkey) !!
                            Any;
            if !($res =:= Any) && nqp::bitand_i($!mode, REQUIRE_DYNAMIC) {
                if !$res.VAR.dynamic {
                    X::Caller::NotDynamic.new(
                        symbol => $key,
                    ).throw;
                }
            }
            $res;
        }
        elsif nqp::bitand_i($!mode, nqp::bitor_i(DYNAMIC_CHAIN, PICK_CHAIN_BY_NAME)) && substr($key, 1, 1) eq '*' {
            my $found := nqp::getlexreldyn(
                nqp::getattr(self, PseudoStash, '$!ctx'),
                $nkey);
            nqp::isnull($found) ?? Any !! $found
        }
        else {
            my $found := nqp::getlexrel(
                nqp::getattr(self, PseudoStash, '$!ctx'),
                $nkey);
            nqp::isnull($found) ?? Any !! $found
        }
    }
    
    method bind_key($key is copy, \value) {
        $key = $key.Str;
        if %pseudoers.exists_key($key) {
            X::Bind.new(target => "pseudo-package $key").throw;
        }
        elsif nqp::bitand_i($!mode, PRECISE_SCOPE) {
            my Mu $store := nqp::getattr(self, EnumMap, '$!storage');
            nqp::bindkey($store, nqp::unbox_s($key), value)
        }
        elsif nqp::bitand_i($!mode, nqp::bitor_i(DYNAMIC_CHAIN, PICK_CHAIN_BY_NAME)) && substr($key, 1, 1) eq '*' {
            die "Binding to dynamic variables not yet implemented";
        }
        else {
            die "This case of binding is not yet implemented";
        }
    }
    method exists_key($key is copy) {
        $key = $key.Str;
        if %pseudoers.exists_key($key) {
            True
        }
        elsif nqp::bitand_i($!mode, PRECISE_SCOPE) {
            nqp::p6bool(nqp::existskey(
                nqp::getattr(self, EnumMap, '$!storage'),
                nqp::unbox_s($key)))
        }
        elsif nqp::bitand_i($!mode, nqp::bitor_i(DYNAMIC_CHAIN, PICK_CHAIN_BY_NAME)) && substr($key, 1, 1) eq '*' {
            nqp::isnull(
                nqp::getlexreldyn(
                    nqp::getattr(self, PseudoStash, '$!ctx'),
                    nqp::unbox_s($key)))
                ?? False !! True
        }
        else {
            nqp::isnull(
                nqp::getlexrel(
                    nqp::getattr(self, PseudoStash, '$!ctx'),
                    nqp::unbox_s($key)))
                ?? False !! True
        }
    }
}

# vim: ft=perl6 expandtab sw=4
