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
record Valence (𝒮 : Set) : Set where
  constructor _⊢_
  no-eta-equality
  field
    ctx : Ctx 𝒮
    sort : 𝒮

open Valence public

map-ctx : {𝒮 : Set} → (Ctx 𝒮 → Ctx 𝒮) → Valence 𝒮 → Valence 𝒮
map-ctx f (Γ ⊢ τ) = f Γ ⊢ τ

MCtx : Set → Set
MCtx 𝒮 = List (Valence 𝒮)

open List using (_++_ ; ◇ ; □)
open Π using (_∘_)

infixr 1 _∣_▹_

-- An abt signature [Σ] is a container [Valence 𝒮 ▹ 𝒮]; we can form the free Σ-model
-- as follows:

data Pattern {𝒮 : Set} (Σ : Valence 𝒮 ▹ 𝒮) (Ψ : MCtx 𝒮) (F : Valence 𝒮 → Set) : Valence 𝒮 → Set where
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

data _∣_▹_ {𝒮 : Set} (Σ : Valence 𝒮 ▹ 𝒮) (Ψ : MCtx 𝒮) (𝓈 : Valence 𝒮) : Set where
  ⟨_⟩ : Pattern Σ Ψ (Σ ∣ Ψ ▹_) 𝓈 → Σ ∣ Ψ ▹ 𝓈

-- the signature of a logical theory is a binding theory with a distinguished
-- sort of «judgments», along with an assignment of valences to the evidence
-- for these judgments.
record Sig : Set₁ where
  no-eta-equality
  field
    𝒮 : Set
    jdg : 𝒮
    sig : Valence 𝒮 ▹ 𝒮
    evd : ∀ {Ψ} → sig ∣ Ψ ▹ [] ⊢ jdg → Valence 𝒮

  judgment : MCtx 𝒮 → Set
  judgment Ψ = sig ∣ Ψ ▹ [] ⊢ jdg

  evidence : {Ψ : MCtx 𝒮} → judgment Ψ → Set
  evidence {Ψ} 𝒿 = sig ∣ Ψ ▹ evd 𝒿

mutual
  data Telescope (L : Sig) (Ψ : MCtx (Sig.𝒮 L)) : Set where
    []
      : Telescope L Ψ
    _⌢_
      : (T : Telescope L Ψ)
      → Sig.judgment L (Ψ ++ ∣ T ∣)
      → Telescope L Ψ

  ∣_∣ : {L : Sig} {Ψ : _} → Telescope L Ψ → MCtx (Sig.𝒮 L)
  ∣ [] ∣ = []
  ∣_∣ {L} (T ⌢ 𝒿) = Sig.evd L 𝒿 ∷ ∣ T ∣

data _∣_⊨_ {𝒮 : Set} (Σ : Valence 𝒮 ▹ 𝒮) (Ψ : MCtx 𝒮) : MCtx 𝒮 → Set where
  [] : Σ ∣ Ψ ⊨ []
  _⌢_ : ∀ {Ψ′ v} → Σ ∣ Ψ ⊨ Ψ′ → Σ ∣ (Ψ ++ Ψ′) ▹ v → Σ ∣ Ψ ⊨ (v ∷ Ψ′)

record State (L : Sig) (Ψ : MCtx (Sig.𝒮 L)) : Set where
  no-eta-equality
  open Sig L
  field
    goal
      : judgment Ψ
    subgoals
      : Telescope L Ψ
    validation
      : sig ∣ Ψ ⊨ ∣ subgoals ∣
      → evidence goal

open State public

η : {L : Sig} {Ψ : _} → Sig.judgment L Ψ → State L Ψ
goal (η 𝒿) = 𝒿
subgoals (η {L = L} {Ψ = Ψ} 𝒿) = [] ⌢ ≡.coe* (Sig.judgment L) (List.⊢.ρ⇐ Ψ) 𝒿
validation (η {L = L} {Ψ = Ψ} 𝒿) (ρ ⌢ e) = ≡.coe* (λ A → A) lemma e
  where
    open Sig L
    lemma : (sig ∣ Ψ ++ [] ▹ evd (≡.coe* (Sig.judgment L) (List.⊢.ρ⇐ Ψ) 𝒿)) ≡ Sig.evidence L 𝒿
    lemma = ≡.ap² (λ { (Ψ′ , 𝒿′) → sig ∣ Ψ′ ▹ 𝒿′ }) (List.⊢.ρ⇒ Ψ , ain't-nobody-got-time-for-this)
      where
        postulate ain't-nobody-got-time-for-this : _
        -- !!! TODO


module LambdaCalculus where

  data 𝒮 : Set where
    val exp : 𝒮

  data 𝒪[Λ] : 𝒮 → Set where
    lam : 𝒪[Λ] val
    ap : 𝒪[Λ] exp
    num : Nat → 𝒪[Λ] val
    thunk : 𝒪[Λ] exp

  Λ : Valence 𝒮 ▹ 𝒮
  𝒪 Λ = 𝒪[Λ]
  𝒜 Λ lam = 𝟙
  𝒜 Λ ap = 𝟚
  𝒜 Λ (num x) = 𝟘
  𝒜 Λ thunk = 𝟙
  𝓋 Λ lam * = (val ∷ []) ⊢ exp
  𝓋 Λ ap ff = [] ⊢ exp
  𝓋 Λ ap tt = [] ⊢ exp
  𝓋 Λ (num x) ()
  𝓋 Λ thunk * = [] ⊢ val

  example : Λ ∣ [] ▹ [] ⊢ val
  example = ⟨ [ lam ▸ (λ {* → ⟨ [ thunk ▸ (λ {* → ⟨ ` ◇.stop refl ⟩}) ] ⟩}) ] ⟩
