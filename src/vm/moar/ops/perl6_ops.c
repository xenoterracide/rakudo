#define MVM_SHARED 1
#include "moar.h"
#include "container.h"

#define GET_REG(tc, idx) (*tc->interp_reg_base)[*((MVMuint16 *)(*tc->interp_cur_op + idx))]

/* Are we initialized yet? */
static int initialized = 0;

/* Types we need. */
static MVMObject *True = NULL;
static MVMObject *False = NULL;

/* Initializes the Perl 6 extension ops. */
static void p6init(MVMThreadContext *tc) {
    if (!initialized) {
        Rakudo_containers_setup(tc);
    }
}

/* Stashes away various type references. */
#define get_type(tc, hash, name, varname) do { \
    MVMString *key = MVM_string_utf8_decode((tc), (tc)->instance->VMString, (name), strlen((name))); \
    (varname) = MVM_repr_at_key_o((tc), (hash), key); \
    MVM_gc_root_add_permanent(tc, (MVMCollectable **)&varname); \
} while (0)
static MVMuint8 s_p6settypes[] = {
    MVM_operand_obj | MVM_operand_read_reg
};
static void p6settypes(MVMThreadContext *tc) {
    MVMObject *conf = GET_REG(tc, 0).o;
    MVMROOT(tc, conf, {
        get_type(tc, conf, "True", True);
        get_type(tc, conf, "False", False);
    });
}

/* Turns zero to False and non-zero to True. */
static MVMuint8 s_p6bool[] = {
    MVM_operand_obj | MVM_operand_write_reg,
    MVM_operand_int64 | MVM_operand_read_reg,
};
static void p6bool(MVMThreadContext *tc) {
     GET_REG(tc, 0).o = GET_REG(tc, 2).i64 ? True : False;
}

/* Type-checks the return value of a routine. */
/* XXX Due to potential nested runloop calls, this may not want doing in C. */
static MVMuint8 s_p6typecheckrv[] = {
    MVM_operand_obj | MVM_operand_read_reg,
    MVM_operand_obj | MVM_operand_read_reg,
};
static void p6typecheckrv(MVMThreadContext *tc) {
     /* XXX */
}

/* Decontainerizes the return value of a routine as needed. */
static MVMuint8 s_p6store[] = {
    MVM_operand_obj | MVM_operand_read_reg,
    MVM_operand_obj | MVM_operand_read_reg,
};
static void p6store(MVMThreadContext *tc) {
     MVM_exception_throw_adhoc(tc, "p6store NYI");
}

/* Decontainerizes the return value of a routine as needed. */
static MVMuint8 s_p6decontrv[] = {
    MVM_operand_obj | MVM_operand_write_reg,
    MVM_operand_obj | MVM_operand_read_reg,
    MVM_operand_obj | MVM_operand_read_reg,
};
static void p6decontrv(MVMThreadContext *tc) {
     /* XXX TODO */
     GET_REG(tc, 0).o = GET_REG(tc, 4).o;
}

static MVMuint8 s_p6capturelex[] = {
    MVM_operand_obj | MVM_operand_write_reg,
    MVM_operand_obj | MVM_operand_read_reg,
};
static void p6capturelex(MVMThreadContext *tc) {
    MVMCode *codeObj = (MVMCode *)GET_REG(tc, 2).o;
    MVMCode *closure;
    MVMStaticFrame *wantedStaticInfo;
    if (REPR(codeObj)->ID != MVM_REPR_ID_MVMCode)
        MVM_exception_throw_adhoc(tc, "p6capturelex needs a code ref");

    closure = (MVMCode *)codeObj->body.code_object;

    wantedStaticInfo = closure->body.sf->body.outer;
    if (tc->cur_frame->static_info == wantedStaticInfo)
        closure->body.outer = tc->cur_frame;
    else if (tc->cur_frame->outer->static_info == wantedStaticInfo)
        closure->body.outer = tc->cur_frame->outer;

    GET_REG(tc, 0).o = (MVMObject *)codeObj;
}

/* Registers the extops with MoarVM. */
MVM_DLL_EXPORT void Rakudo_ops_init(MVMThreadContext *tc) {
    MVM_ext_register_extop(tc, "p6init",  p6init, 0, NULL);
    MVM_ext_register_extop(tc, "p6settypes",  p6settypes, 1, s_p6settypes);
    MVM_ext_register_extop(tc, "p6bool",  p6bool, 2, s_p6bool);
    MVM_ext_register_extop(tc, "p6typecheckrv",  p6typecheckrv, 2, s_p6typecheckrv);
    MVM_ext_register_extop(tc, "p6store",  p6store, 2, s_p6store);
    MVM_ext_register_extop(tc, "p6decontrv",  p6decontrv, 3, s_p6decontrv);
    MVM_ext_register_extop(tc, "p6capturelex",  p6capturelex, 2, s_p6capturelex);
}