
signature LCF_TACTIC_MONAD = 
sig
  include MONAD

  type env (* local state *)

  val run : env -> 'a m * ('a -> bool) -> 'a

  val throw : exn -> 'a m
  val par : 'a m * 'a m -> 'a m
  val or : 'a m * 'a m -> 'a m

  val getEnv : env m
  val mapEnv : (env -> env) -> 'a m -> 'a m
  val mapErr : (exn -> exn) -> 'a m -> 'a m
end

signature LCF_TACTIC =
sig
  include LCF

  structure J : LCF_JUDGMENT where type sort = L.sort and type env = L.term L.Ctx.dict

  type jdg = J.jdg
  val isjdg : jdg isjdg

  structure R : MONAD
  structure M : LCF_TACTIC_MONAD

  type 'a rule = 'a -> 'a state R.m
  type 'a tactic = 'a -> 'a state M.m
  type 'a multitactic = 'a state tactic

  val rule : 'a rule -> 'a tactic

  val matchGoal : ('a -> 'a tactic) -> 'a tactic

  val mapEnv : (M.env -> M.env) -> 'a tactic -> 'a tactic

  val all : jdg tactic -> jdg multitactic
  val each : jdg tactic list -> jdg multitactic
  val only : int * jdg tactic -> jdg multitactic

  val allSeq : jdg tactic -> jdg multitactic
  val eachSeq : jdg tactic list -> jdg multitactic

  val seq : jdg tactic * jdg multitactic -> jdg tactic
  val then_ : jdg tactic * jdg tactic -> jdg tactic
  val thenl : jdg tactic * jdg tactic list -> jdg tactic
  val thenf : jdg tactic * (int * jdg tactic) -> jdg tactic

  val idn : jdg tactic
  val orelse_ : jdg tactic * jdg tactic -> jdg tactic
  val par : jdg tactic * jdg tactic -> jdg tactic
  val mpar : jdg tactic * jdg tactic -> jdg tactic
  val try : jdg tactic -> jdg tactic

  val morelse : jdg multitactic * jdg multitactic -> jdg multitactic

  exception Progress
  val progress : jdg tactic -> jdg tactic
  val mprogress : jdg multitactic -> jdg multitactic

  exception Complete
  val complete : jdg tactic -> jdg tactic
end