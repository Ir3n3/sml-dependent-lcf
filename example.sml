structure Sort : SORT =
struct
  type t = unit
  val eq = op=
  fun toString () = "exp"
end

structure Valence = Valence (structure Sort = Sort and Spine = ListSpine)
structure Arity = Arity (Valence)

structure O =
struct
  structure Arity = Arity

  datatype 'i t =
      UNIT
    | SIGMA
    | AX
    | PAIR
    | FOO (* a dummy proposition to demonstrate dependency *)

  fun eq _ =
    fn (UNIT, UNIT) => true
     | (SIGMA, SIGMA) => true
     | (AX, AX) => true
     | (PAIR, PAIR) => true
     | (FOO, FOO) => true
     | _ => false

  fun arity UNIT = ([], ())
    | arity SIGMA = ([(([],[]),()), (([], [()]), ())], ())
    | arity AX = ([], ())
    | arity PAIR = ([(([],[]),()), (([], []), ())], ())
    | arity FOO = ([(([],[]),()), (([], []), ())], ())

  fun map _ =
    fn UNIT => UNIT
     | SIGMA => SIGMA
     | AX => AX
     | PAIR => PAIR
     | FOO => FOO

  fun support _ = []

  fun toString _ UNIT = "Unit"
    | toString _ SIGMA = "Σ"
    | toString _ AX = "Ax"
    | toString _ PAIR = "Pair"
    | toString _ FOO = "Foo"
end

structure V = Symbol ()
structure Lbl =
struct
  open V
  fun prime x = named (toString x ^ "'")
end

structure Term = Abt (structure Operator = O and Variable = V and Symbol = V and Metavariable = V)

structure Kit =
struct
  structure Term = Term and Telescope = Telescope (Lbl)
  structure ShowTm = DebugShowAbt (Term)
  datatype judgment = TRUE of Term.abt
  fun judgmentToString (TRUE p) =
    ShowTm.toString p ^ " true"

  fun evidenceValence _ = (([], []), ())
  fun substJudgment (x, e) (TRUE p) =
    TRUE (Term.metasubst (e,x) p)
end
structure Lcf = DepLcf (Kit)

signature REFINER =
sig
  val UnitIntro : Lcf.tactic
  val SigmaIntro : Lcf.tactic
  val FooIntro : Lcf.tactic
end

structure Refiner :> REFINER =
struct
  open Kit Term
  infix $ $# \

  structure T = Telescope
  fun >: (T, p) = T.snoc T p
  infix >:

  structure MC =
  struct
    open MetaCtx
    structure Util = ContextUtil (structure Ctx = MetaCtx and Elem = Valence)
    open Util
  end

  fun teleToMctx (tele : judgment T.telescope) =
    let
      open T.ConsView
      fun go Empty theta = theta
        | go (Cons (l, jdg, psi)) theta =
            go (out psi) (MC.extend theta (l, evidenceValence jdg))
    in
      go (out tele) MC.empty
    end


  local
    val i = ref 0
  in
    fun newMeta str =
      (i := !i + 1;
       V.named (str ^ Int.toString (!i)))
  end

  fun UnitIntro (TRUE P) =
    let
      val O.UNIT $ [] = out P
      val psi = T.empty
      val theta = teleToMctx psi
      val ax = check theta (O.AX $ [], ())
    in
      (psi, (fn rho => abtToAbs ax))
    end

  fun SigmaIntro (TRUE P) =
    let
      val O.SIGMA $ [_ \ A, (_, [x]) \ B] = out P
      val a = newMeta "?a"
      val b = newMeta "?b"
      val psi1 = T.empty >: (a, TRUE A)
      val theta1 = teleToMctx psi1
      val Ba = subst (check theta1 (a $# ([],[]), ()), x) B
      val psi = psi1 >: (b, TRUE Ba)
      val theta = teleToMctx psi
    in
      (psi, (fn rho =>
        let
          val (a', _) = inferb (T.lookup rho a)
          val (b', _) = inferb (T.lookup rho b)
          val pair = check theta (O.PAIR $ [a', b'], ())
        in
          abtToAbs pair
        end))
    end

  fun FooIntro (TRUE P) =
    let
      val O.FOO $ [_ \ A, _] = out P
      val a = newMeta "?a"
      val psi = T.empty >: (a, TRUE A)
      val theta = teleToMctx psi
      val ax = check theta (O.AX $ [], ())
    in
      (psi, (fn rho =>
        T.lookup rho a))
    end

end

structure Example =
struct
  open Refiner Kit
  open Lcf Term
  structure ShowTm = PlainShowAbt (Term)
  infix 5 $ \ THEN ORELSE

  val x = Variable.named "x"

  val subgoalsToString =
    Telescope.toString (fn (TRUE p) => ShowTm.toString p ^ " true")

  fun run goal (tac : tactic) =
    let
      val state = tac goal
    in
      print ("\n\n" ^ Lcf.stateToString state ^ "\n\n")
    end

  val mkUnit = check' (O.UNIT $ [], ())
  fun mkSigma x a b = check' (O.SIGMA $ [([],[]) \ a, ([],[x]) \ b], ())
  fun mkFoo a b = check' (O.FOO $ [([],[]) \ a, ([],[]) \ b], ())

  val x = Variable.named "x"
  val y = Variable.named "y"

  val goal =
    mkSigma y
      (mkSigma x mkUnit mkUnit)
      (mkFoo mkUnit (check' (`y, ())))

  (* to interact with the refiner, try commenting out some of the following lines *)
  val script =
    SigmaIntro
      THEN TRY SigmaIntro
      THEN TRY UnitIntro
      THEN FooIntro
      THEN UnitIntro

  val _ = run (TRUE goal) script
end

