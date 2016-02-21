module theory where

open import Agda.Primitive
open import Prelude.List
open import Prelude.Monoidal
open import Prelude.Natural
open import Prelude.Bool
open import Prelude.List
open import Prelude.Path

-- indexed containers, or «interaction structures»; [J] is the state of the parent,
-- and [I] is the state yielded to the children. In the case of a second-order algebraic
-- theory, [J] will be the set of sorts, and [I] will be the set of valences.
record _▹_ {i} (I J : Set i) : Set (lsuc i) where
  constructor _◃_$_
  no-eta-equality
  field
    -- the set of «operators» at each sort
    𝒪 : J → Set i

    -- the «arity» of an operator
    𝒜 : {τ : J} → 𝒪 τ → Set i

    -- the «valence» of an argument to an operator
    𝓋 : {τ : J} (ϑ : 𝒪 τ) → 𝒜 ϑ → I

  -- the extension of an indexed container; this is analogous to the signature endofunctor
  𝔉[_] : (I → Set i) → (J → Set i)
  𝔉[_] X τ = Σ[ 𝒪 τ ∋ ϑ ] Π[ 𝒜 ϑ ∋ 𝒶 ] X (𝓋 ϑ 𝒶)

open _▹_ public

Ctx : Set → Set
Ctx 𝒮 = List 𝒮

infixr 2 _⊢_
record Sequent (𝒮 : Set) : Set where
  constructor _⊢_
  no-eta-equality
  field
    ctx : Ctx 𝒮
    sort : 𝒮

open Sequent public

map-ctx : {𝒮 : Set} → (Ctx 𝒮 → Ctx 𝒮) → Sequent 𝒮 → Sequent 𝒮
map-ctx f (Γ ⊢ τ) = f Γ ⊢ τ

MCtx : Set → Set
MCtx 𝒮 = List (Sequent 𝒮)

open List using (_++_ ; ◇ ; □)
open Π using (_∘_)

infixr 1 _∣_▹_

-- An abt signature [Σ] is a container [Sequent 𝒮 ▹ 𝒮]; we can form the free Σ-model
-- as follows:

data Pattern {𝒮 : Set} (Σ : Sequent 𝒮 ▹ 𝒮) (Ψ : MCtx 𝒮) (F : Sequent 𝒮 → Set) : Sequent 𝒮 → Set where
  -- metavariables
  #_[_]
    : ∀ {Γ Δ τ}
    → ◇ (_≡ Δ ⊢ τ) Ψ  -- metavariable in metacontext
    → □ (F ∘ Γ ⊢_) Δ  -- arguments
    → Pattern Σ Ψ F (Γ ⊢ τ)

  -- variables
  `_
    : ∀ {Γ τ}
    → ◇ (_≡ τ) Γ      -- variable in context
    → Pattern Σ Ψ F (Γ ⊢ τ)

  -- operators
  [_]
    : ∀ {Γ τ}
    → 𝔉[ Σ ] (F ∘ map-ctx (Γ ++_)) τ
    → Pattern Σ Ψ F (Γ ⊢ τ)

data _∣_▹_ {𝒮 : Set} (Σ : Sequent 𝒮 ▹ 𝒮) (Ψ : MCtx 𝒮) (𝓈 : Sequent 𝒮) : Set where
  ⟨_⟩ : Pattern Σ Ψ (Σ ∣ Ψ ▹_) 𝓈 → Σ ∣ Ψ ▹ 𝓈

module LambdaCalculus where

  data 𝒮 : Set where
    val exp : 𝒮

  data 𝒪[Λ] : 𝒮 → Set where
    lam : 𝒪[Λ] val
    ap : 𝒪[Λ] exp
    num : Nat → 𝒪[Λ] val
    thunk : 𝒪[Λ] exp

  Λ : Sequent 𝒮 ▹ 𝒮
  𝒪 Λ = 𝒪[Λ]
  𝒜 Λ lam = 𝟙
  𝒜 Λ ap = 𝟚
  𝒜 Λ (num x) = 𝟘
  𝒜 Λ thunk = 𝟙
  𝓋 Λ lam 𝟙↑.* = (val ∷ []) ⊢ exp
  𝓋 Λ ap 𝟚↑.ff = [] ⊢ exp
  𝓋 Λ ap 𝟚↑.tt = [] ⊢ exp
  𝓋 Λ (num x) ()
  𝓋 Λ thunk 𝟙↑.* = [] ⊢ val

  example : Λ ∣ [] ▹ [] ⊢ val
  example = ⟨ [ lam ▸ (λ {* → ⟨ [ thunk ▸ (λ {* → ⟨ ` ◇.stop refl ⟩}) ] ⟩}) ] ⟩
