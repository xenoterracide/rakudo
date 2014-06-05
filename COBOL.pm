
use v6;
#~ use NQPCursor:from<NQP>;

grammar COBOL::Grammar {
    #~ token statementlist($bootint) {
    token statementlist(|) {
        <!!{ say("in COBOLs statementlist") }>
        a
    }
    #~ method statementlist($bootint) {
        #~ say $bootint.HOW.name($bootint);
        #~ NQPCursor.new;
    #~ }
};

class COBOL::Actions {
    method statementlist($/) {
        say 'yay'
    }
}

sub EXPORT(*@a) {
    %*LANG<COBOL>         := COBOL::Grammar;
    %*LANG<COBOL-actions> := COBOL::Actions;
    $*MAIN                := 'COBOL';

    $*W.install_lexical_symbol($*W.cur_lexpad(), '%?LANG', $*W.p6ize_recursive(%*LANG));
    $*W.install_lexical_symbol($*W.cur_lexpad(), '$*MAIN', $*W.p6ize_recursive($*MAIN));

    $*W.p6ize_recursive( nqp::hash() )
}
