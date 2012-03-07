%% File: leancop_dnf.pl  -  Version: 1.15  -  Date: 2011
%%
%% Purpose: Call the leanCoP core prover for a given formula with a machine learning server.
%%
%% Authors: Jiri Vyskocil
%%
%% Usage:   leancop_dnf(X,S,R). % proves formula in file X with
%%                               %  settings S and returns result R
%%
%% Copyright: (c) 2010 by Jiri Vyskocil
%% License:   GNU General Public License

:- dynamic(ai_advisor/0). % with format: ai_advisor(server_location:port)

:- [leancop_main].

:- [tcp_client].

:- op(100,fy,-). % due to problems with -3^[] as (-3)^[] instead of -(3^[])
	
load_dnf(File,Ls) :-
    open(File,read,Stream), 
    ( findall(dnf(Index,Type,Cla,G),(repeat,read(Stream,T),(T \== end_of_file -> T=dnf(Index,Type,Cla,G) ; (!,fail))),Ls)
    -> close(Stream) ; close(Stream), fail ).


leancop_dnf(File,Settings,Result) :-
%    axiom_path(AxPath), ( AxPath='' -> AxDir='' ;
%    name(AxPath,AxL), append(AxL,[47],DirL), name(AxDir,DirL) ),
%    ( leancop_tptp2(File,AxDir,[_],F,Conj) ->
%      Problem=F ; [File], f(Problem), Conj=non_empty ),
%    ( Conj\=[] -> Problem1=Problem ; Problem1=(~Problem) ),
%    leancop_equal(Problem1,Problem2),
%    make_matrix(Problem2,Matrix,Settings),
    Conj=non_empty,
    load_dnf(File,Matrix),
    ai_advisor(DNS:PORT),
    create_client(DNS:PORT,Advisor_In,Advisor_Out),
    
    ( prove2(Matrix,Settings,Advisor_In,Advisor_Out,Proof) ->
      ( Conj\=[] -> Result='Theorem' ; Result='Unsatisfiable' ) ;
      ( Conj\=[] -> Result='Non-Theorem' ; Result='Satisfiable' )
    ),
    close_connection(Advisor_In,Advisor_Out),
    output_result(File,Matrix,Proof,Result,Conj).

%% File: leancop21_swi.pl  -  Version: 2.1  -  Date: 30 Aug 2008
%%
%%         "Make everything as simple as possible, but not simpler."
%%                                                 [Albert Einstein]
%%
%% Purpose: leanCoP: A Lean Connection Prover for Classical Logic
%%
%% Author:  Jens Otten
%% Web:     www.leancop.de
%%
%% Usage: prove(M,P).    % where M is a set of clauses and P is
%%                       %  the returned connection proof
%%                       %  e.g. M=[[q(a)],[-p],[p,-q(X)]]
%%                       %  and  P=[[q(a)],[[-(q(a)),p],[[-(p)]]]]
%%        prove(F,P).    % where F is a first-order formula and
%%                       %  P is the returned connection proof
%%                       %  e.g. F=((p,all X:(p=>q(X)))=>all Y:q(Y))
%%                       %  and  P=[[q(a)],[[-(q(a)),p],[[-(p)]]]]
%%        prove2(F,S,P). % where F is a formula, S is a subset of
%%                       %  [nodef,def,conj,reo(I),scut,cut,comp(J)]
%%                       %  (with numbers I,J) defining attributes
%%                       %  and P is the returned connection proof
%%
%% Copyright: (c) 1999-2008 by Jens Otten
%% License:   GNU General Public License


% :- [def_mm].  % load program for clausal form translation
:- dynamic(lit/5).

%%% best_lit
%%% finds best lit according to a machine learning advisor.
/*best_lit(Advisor_In,Advisor_Out,NegLit,Clause,Ground) :-
         lit(NegLit,NegL,Clause,Ground,_IDX),
         unify_with_occurs_check(NegL,NegLit).
*/
best_lit(Advisor_In,Advisor_Out,NegLit,Clause,Ground) :-
         collect_symbols_top([NegLit],Ps,Fs),
         append(Ps,Fs,Ss),
         write(Advisor_Out,Ss),nl(Advisor_Out),
         read(Advisor_In,Indexes),!,
         (
		 ( member(I,Indexes),
		   lit(NegLit,NegL,Clause,Ground,I),
		   unify_with_occurs_check(NegL,NegLit)
		 )
/*		  ;
		 (
		   lit(NegLit,NegL,Clause,Ground,I),
		   \+ member(I,Indexes),
		   unify_with_occurs_check(NegL,NegLit)
		 )
*/         ).

%%% collect nonvar symbols from term

collect_symbols_top(Xs,Ps,Ls):-
        maplist(collect_predicate_symbols,Xs,Qs,LRs),
        sort(Qs,Ps),
        append(LRs,Rs),
	maplist(collect_symbols,Rs,L1),!,
	append(L1,L2),
	flatten(L2,L3),
	sort(L3,Ls).

collect_predicate_symbols(-X,P,As) :- X=..[P|As].
collect_predicate_symbols(X,P,As)  :- X=..[P|As].

collect_predicate_symbols([],[]).

collect_symbols(X,[]):- var(X),!.
collect_symbols(X,[X]):- atomic(X),!.
collect_symbols(X1,T2):-
	X1 =.. [H1|T1],
	maplist(collect_symbols,T1,T3),
	append(T3,T4),
	flatten(T4,T5),
	sort([H1|T5],T2).

%%% prove matrix M / formula F

prove(F,Advisor_In,Advisor_Out,Proof) :- prove2(F,[cut,comp(7)],Advisor_In,Advisor_Out,Proof).

prove2(M,Set,Advisor_In,Advisor_Out,Proof) :-
    retractall(lit(_,_,_,_,_)), (member(dnf(_,_,[-(#)],_),M) -> S=conj ; S=pos),
    assert_clauses(M,/*S*/conj), 
    prove(1,Set,Advisor_In,Advisor_Out,Proof).

prove(PathLim,Set,Advisor_In,Advisor_Out,Proof) :-
    \+member(scut,Set) -> prove([-(#)],[],PathLim,[],Set,Advisor_In,Advisor_Out,[Proof]) ;
    lit(#,_,C,_,_) -> prove(C,[-(#)],PathLim,[],Set,Advisor_In,Advisor_Out,Proof1),
    Proof=[C|Proof1].
prove(PathLim,Set,Advisor_In,Advisor_Out,Proof) :-
    member(comp(Limit),Set), PathLim=Limit -> prove(1,[],Advisor_In,Advisor_Out,Proof) ;
    (member(comp(_),Set);retract(pathlim)) ->
    PathLim1 is PathLim+1, prove(PathLim1,Set,Advisor_In,Advisor_Out,Proof).

%%% leanCoP core prover

prove([],_,_,_,_,_,_,[]).

prove([Lit|Cla],Path,PathLim,Lem,Set,Advisor_In,Advisor_Out,Proof) :-
    Proof=[[[NegLit|Cla1]|Proof1]|Proof2],
    \+ (member(LitC,[Lit|Cla]), member(LitP,Path), LitC==LitP),
    (-NegLit=Lit;-Lit=NegLit) ->
       ( member(LitL,Lem), Lit==LitL, Cla1=[], Proof1=[]
         ;
         member(NegL,Path), unify_with_occurs_check(NegL,NegLit),
         Cla1=[], Proof1=[]
         ;
         best_lit(Advisor_In,Advisor_Out,NegLit,Cla1,Grnd1),
%         lit(NegLit,NegL,Cla1,Grnd1,_IDX),
%         unify_with_occurs_check(NegL,NegLit),
         ( Grnd1=g -> true ; length(Path,K), K<PathLim -> true ;
           \+ pathlim -> assert(pathlim), fail ),
         prove(Cla1,[Lit|Path],PathLim,Lem,Set,Advisor_In,Advisor_Out,Proof1)
       ),
       ( member(cut,Set) -> ! ; true ),
       prove(Cla,Path,PathLim,[Lit|Lem],Set,Advisor_In,Advisor_Out,Proof2).


%%% write clauses into Prolog's database

assert_clauses([],_).
assert_clauses([dnf(Index,_,C,G)|M],Set) :-
    (Set\=conj, \+member(-_,C) -> C1=[#|C] ; C1=C),
%    copy_term(C1,X),numbervars(X,1,_), print(X), nl,
    assert_clauses2(C1,[],G,Index),
    assert_clauses(M,Set).

assert_clauses2([],_,_,_).
assert_clauses2([L|C],C1,G,Index) :-
    assert_renvar([L],[L2]), append(C1,C,C2), append(C1,[L],C3),
    assert(lit(L2,L,C2,G,Index)), assert_clauses2(C,C3,G,Index).

assert_renvar([],[]).
assert_renvar([F|FunL],[F1|FunL1]) :-
    ( var(F) -> true ; F=..[Fu|Arg], assert_renvar(Arg,Arg1),
      F1=..[Fu|Arg1] ), assert_renvar(FunL,FunL1).

%%% output of leanCoP proof

leancop_proof(Mat,Proof) :-
    proof(compact) -> leancop_compact_proof(Proof) ;
    proof(connect) -> leancop_connect_proof(Mat,Proof) ;
    proof(readable_with_global_index) -> leancop_readable_proof_with_global_index(Mat,Proof) ;
    leancop_readable_proof(Mat,Proof).

%%% print readable proof with global index of clauses

leancop_readable_proof_with_global_index(Mat,Proof) :-
    print('------------------------------------------------------'),
    nl,
    print_explanations,
    print('Proof:'), nl, print('------'), nl, nl,
    print('Translation into (disjunctive) clausal form:'), nl,
    print_dnf(Mat,Mat1),
    print_introduction,
    calc_proof_with_global_index(Mat1,Mat,Proof,Proof1),
    print_proof(Proof1), nl,
    print_ending,
    print('------------------------------------------------------'),
    nl.

%%% print dnf clauses, print index number, print spaces

print_dnf([],[]) :- nl.
print_dnf([[dnf(_,_,-(#),_)]|Mat],Mat1) :- !, print_dnf(Mat,Mat1).
print_dnf([dnf(I,Type,Cla,G)|Mat],Mat1) :-
    append(Cla2,[#|Cla3],Cla),append(Cla2,Cla3,Cla1),
    print_dnf([dnf(I,Type,Cla1,G)|Mat],Mat1).
print_dnf([dnf(I,_Type,Cla,_G)|Mat],[Cla|Mat1]) :-
    print(' ('), print(I), print(')  '),
    print(Cla), nl, print_dnf(Mat,Mat1).

%%% calculate leanCoP proof

calc_proof_with_global_index(Mat,DNF_Mat,[Cla|Proof],[(Cla1,Num,Sub)|Proof1]) :-
    ((Cla=[#|Cla1];Cla=[-!|Cla1]) -> true ; Cla1=Cla),
    clause_num_sub_with_global_index(Cla1,[],[],Mat,DNF_Mat,1,Num,Sub),
    calc_proof_with_global_index(Cla1,[],[],Mat,DNF_Mat,Proof,Proof1).

calc_proof_with_global_index(_,_,_,_,_,[],[]).

calc_proof_with_global_index(Cla,Path,Lem,Mat,DNF_Mat,[[Cla1|Proof]|Proof2],Proof1) :-
    append(Cla2,[#|Cla3],Cla1), !, append(Cla2,Cla3,Cla4),
    append(Pro1,[[[-(#)]]|Pro2],Proof), append(Pro1,Pro2,Proof3),
    calc_proof_with_global_index(Cla,Path,Lem,Mat,DNF_Mat,[[Cla4|Proof3]|Proof2],Proof1).

calc_proof_with_global_index([Lit|Cla],Path,Lem,Mat,DNF_Mat,[[Cla1|Proof]|Proof2],Proof1) :-
    (-NegLit=Lit;-Lit=NegLit), append(Cla2,[NegL|Cla3],Cla1),
    NegLit==NegL, append(Cla2,Cla3,Cla4), length([_|Path],I) ->
      clause_num_sub_with_global_index(Cla1,Path,Lem,Mat,DNF_Mat,1,Num,Sub),
      Proof1=[[([NegLit|Cla4],Num,Sub)|Proof3]|Proof4],
      calc_proof_with_global_index(Cla4,[I:Lit|Path],Lem,Mat,DNF_Mat,Proof,Proof3),
      (Lem=[I:J:_|_] -> J1 is J+1 ; J1=1),
      calc_proof_with_global_index(Cla,Path,[I:J1:Lit|Lem],Mat,DNF_Mat,Proof2,Proof4).

%%% determine clause number and substitution

clause_num_sub_with_global_index([NegLit],Path,Lem,[],DNF_Mat,_,R:Num,[[],[]]) :-
    (-NegLit=Lit;-Lit=NegLit), member(Num:J:LitL,Lem), LitL==Lit ->
    R=J ; member(Num:NegL,Path), NegL==NegLit -> R=r.

clause_num_sub_with_global_index(Cla,Path,Lem,[Cla1|Mat],DNF_Mat,I,Num,Sub) :-
    append(Cla2,[L|Cla3],Cla1), append([L|Cla2],Cla3,Cla4),
    instance1(Cla,Cla4) ->
      nth_element(I,DNF_Mat,dnf(Num,_,_,_)), term_variables(Cla4,Var), copy_term(Cla4,Cla5),
      term_variables(Cla5,Var1), Cla=Cla5, Sub=[Var,Var1] ;
      I1 is I+1, clause_num_sub_with_global_index(Cla,Path,Lem,Mat,DNF_Mat,I1,Num,Sub).

nth_element(1,[E|_],E) :- !.
nth_element(I,[_|Ls],E) :- I1 is I - 1, nth_element(I1,Ls,E).
      
      