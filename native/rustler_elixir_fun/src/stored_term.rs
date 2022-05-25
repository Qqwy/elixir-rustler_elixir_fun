use rustler::types::atom::Atom;
use rustler::types::tuple::get_tuple;
use rustler::types::tuple::make_tuple;
use rustler::Decoder;
use rustler::Encoder;
use rustler::Env;
use rustler::LocalPid;
use rustler::NifResult;
use rustler::Term;

mod term_box;
use term_box::TermBox;

/// A StoredTerm is an arbitrary Elixir/Erlang term
/// which no longer is bound to the calling NIF `Env`.
/// As such, these values can be freely stored and used in any Rust code.
///
/// For 'common' types such as (small) integers, floats, atoms, tuples, lists, strings and PIDS,
/// we store a Rust alternative datastructure which can be inspected and used.
///
/// For 'rare' types such as functions, references, ports, bignums (integers larger than fits in an i64), exceptions,
/// and 'unknown types' that might be added to a new version of OTP after this code was compiled,
/// we create a `TermBox` instead.
/// That is, we copy the opaque Erlang term to an `OwnedEnv` (a 'process-independent environment')
/// from which it can be extracted later.
/// This means however that these kinds of terms:
/// - Cannot be manipulated in Rust
/// - Take a bit more overhead to store w.r.t. the common types.
#[derive(Clone)]
pub enum StoredTerm {
    Integer(i64),
    Float(f64),
    AnAtom(Atom),
    Tuple(Vec<StoredTerm>),
    EmptyList(),
    List(Vec<StoredTerm>),
    Bitstring(String),
    Pid(LocalPid),
    Other(TermBox),
}

impl Encoder for StoredTerm {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            StoredTerm::Integer(inner) => inner.encode(env),
            StoredTerm::Float(inner) => inner.encode(env),
            StoredTerm::AnAtom(inner) => inner.encode(env),
            StoredTerm::Tuple(inner) => {
                let terms: Vec<_> = inner.iter().map(|t| t.encode(env)).collect();
                make_tuple(env, terms.as_ref()).encode(env)
            }
            StoredTerm::EmptyList() => rustler::Term::list_new_empty(env),
            StoredTerm::List(inner) => inner.encode(env),
            StoredTerm::Bitstring(inner) => inner.encode(env),
            StoredTerm::Pid(inner) => inner.encode(env),
            StoredTerm::Other(inner) => inner.get(env),
        }
    }
}

fn convert_to_stored_term(term: &Term) -> StoredTerm {
    match term.get_type() {
        rustler::TermType::Atom => term
            .decode()
            .map(StoredTerm::AnAtom)
            .expect("get_type() returned Atom but could not decode as atom?!"),
        rustler::TermType::Binary => term
            .decode()
            .map(StoredTerm::Bitstring)
            .expect("get_type() returned Binary but could not decode as binary?!"),
        rustler::TermType::Number => term
            .decode::<i64>()
            .map(StoredTerm::Integer)
            .or_else(|_| term.decode::<f64>().map(StoredTerm::Float))
            .unwrap_or_else(|_| StoredTerm::Other(TermBox::new(term))), // <- To handle bignums
        rustler::TermType::EmptyList => StoredTerm::EmptyList(),
        rustler::TermType::List => {
            let items = term
                .decode::<Vec<Term>>()
                .expect("get_type() returned List but could not decode as list?!");
            let converted_items = items.iter().map(convert_to_stored_term).collect();

            StoredTerm::List(converted_items)
        }
        rustler::TermType::Tuple => {
            let elems = get_tuple(*term)
                .expect("get_type() returned Tuple but could not decode as tuple?!");
            let converted_elems = elems.iter().map(convert_to_stored_term).collect();
            StoredTerm::Tuple(converted_elems)
        }
        rustler::TermType::Pid => term
            .decode()
            .map(StoredTerm::Pid)
            .expect("get_type() returned Pid but couold not decode as LocalPid?"),
        _other => StoredTerm::Other(TermBox::new(term)),
    }
}

/// The Encoder implementation for StoredTerm will never fail
/// as any Erlang type can be converted to a StoredTerm.
impl<'a> Decoder<'a> for StoredTerm {
    fn decode(term: Term) -> NifResult<Self> {
        Ok(convert_to_stored_term(&term))
    }
}
