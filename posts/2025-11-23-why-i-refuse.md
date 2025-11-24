---
title: Why I refuse to learn type-level programming in Haskell
author: joomy
tags: haskell, ocaml
description: A short essay about why I refuse to learn complex language features like type-level programming in Haskell and first-class modules in OCaml.
---

Haskell, as it was for many, was my "gateway drug" into programming language theory. As I became accustomed to the ways I can express more of my program in the types and [make illegal states unrepresentable](https://blog.janestreet.com/effective-ml-revisited/), I started dabbling in [many different extensions of GHC](https://blog.ocharles.org.uk/pages/2014-12-01-24-days-of-ghc-extensions.html). At this point, I had seen code using some of the most advanced features, libraries, and use cases of Haskell, such as the [singletons](https://hackage.haskell.org/package/singletons) library, but I had barely written anything that went that far.

Soon after I started learning [Agda](https://agda.readthedocs.io/) and [Rocq](https://rocq-prover.org/), I realized that a lot of what Haskell type-level wizardry is trying to do is a lot easier to achieve in these languages. This will be obvious to many, but here's a quick list of how things are easier in the dependently typed setting (mostly Rocq since I know it better than Agda or Lean):

* No need for Haskell's `DataKinds`: You can already use values in types in Rocq. 
* No need for Haskell's `GADTs`: parameters and indices of inductive types already subsume them. 
* No need for Haskell's `KindSignatures`: They are just type annotations on parameters and indices of inductive types.

<div class="code-pair">
<div>
```haskell
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}

data Status = Open | Closed

-- With DataKinds, Status is also a kind,
-- and Open/Closed are type-level constructors.
data Door (s :: Status) where
  MkOpen   :: Door 'Open
  MkClosed :: Door 'Closed

closeDoor :: Door 'Open -> Door 'Closed
closeDoor MkOpen = MkClosed
```
</div><div>
```ocaml
Inductive status : Type :=
| Open
| Closed.

(* status is just a normal type of values,
   and we can index by those values directly. *)
Inductive door : status -> Type :=
| MkOpen  : door Open
| MkClosed : door Closed.

Definition close_door (d : door Open) : door Closed :=
  match d with
  | MkOpen => MkClosed
  end.
```
</div>
</div>

* No need for Haskell's `TypeApplications`. You can always use `@` in Rocq before a type or function to apply types and implicit arguments explicitly. e.g. `cons true nil` can be `@cons bool true (@nil bool)`.
* No need for Haskell's `ScopedTypeVariables`. Type variables are just like any other argument. If the inner helper function does not parametrize over a type `A` that the outer function parametrizes on, the inner type `A` will be the same as the outer `A`.

<div class="code-pair">
<div>
```haskell
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeApplications      #-}

foo :: forall a. [a] -> a
foo xs = headOrDefault xs
  where
    -- This 'a' refers to the *same* 'a as in foo's type.
    def :: a
    def = error "empty list"

    headOrDefault :: [a] -> a
    headOrDefault []    = def
    headOrDefault (y:_) = y

--  We use TypeApplications to fix 'a' to Int explicitly
example :: Int
example = foo @Int [1, 2, 3]
```
</div><div>
```ocaml
From Stdlib Require Import List.
Import ListNotations.

Definition foo {A : Type} (xs : list A) : option A :=
  (* Inner definitions see the same A automatically. *)
  let default : option A := None in
  let head_or_default (ys : list A) : option A :=
      match ys with
      | [] => default
      | x :: _ => Some x
      end
  in
  head_or_default xs.

(* Here we use @foo nat ... 
   to explicitly apply the type argument. *)
Definition example : option nat :=
  @foo nat [1; 2; 3].
```
</div>
</div>

* Rocq already has type classes, but they're essentially records with some instance search mechanism (for which Rocq's proof search and hint system is used). A one-parameter type class is just a record that is parametrized by a `Type` in Rocq.
* No need for Haskell's `ConstraintKinds`. For type class constraints, `Type` suffices, since records are just types (or `Prop` or whatever sort you pick). Equality constraints can also be `Type` since `x = y` is of sort `Prop` (for some `x` and `y`).

<div class="code-pair">
<div>
```haskell
{-# LANGUAGE ConstraintKinds #-}

import Data.Kind (Constraint)

type EqShow a = (Eq a, Show a) :: Constraint

describe :: EqShow a => a -> a -> String
describe x y =
  if x == y
     then "same: " ++ show x
     else "different: " ++ show x ++ " vs " ++ show y
```
</div><div>
```ocaml
From Stdlib Require Import String.
Open Scope string_scope.

Class Eq (A : Type) := { eqb : A -> A -> bool }.
Class Show (A : Type) := { show : A -> string }.

(* Using the substructures feature of Rocq type classes: *)
Class EqShow (A : Type) :=
  { EqShow_Eq :: Eq A
  ; EqShow_Show :: Show A
  }.

Definition describe {A : Type} `{EqShow A} (x y : A) : string :=
  if eqb x y
  then "same: " ++ show x
  else "different: " ++ show x ++ " vs " ++ show y.
```
</div>
</div>

* No need for Haskell's `MultiParamTypeClasses`. It's just a record that is parametrized by multiple types in Rocq, which is fair game.

<div class="code-pair">
<div>
```haskell
{-# LANGUAGE MultiParamTypeClasses #-}

-- A multi-parameter type class
class Convert a b where
  convert :: a -> b

instance Convert Bool Int where
  convert True  = 1
  convert False = 0
```
</div><div>
```ocaml
Class Convert (A B : Type) := { convert : A -> B }.

Instance Convert_bool_nat : Convert bool nat :=
  {| convert b := if b then 1 else 0 |}.
```
</div>
</div>

* No need for Haskell's `FlexibleInstances`. An instance is a record with a particular type, which may be parametrized or indexed by anything (if the type requires it).

<div class="code-pair">
<div>
```haskell
{-# LANGUAGE FlexibleInstances #-}

class MyClass a

instance MyClass (Maybe a)

-- requires FlexibleInstances:
instance MyClass (Maybe Int)
```
</div><div>
```ocaml
Class MyClass (A : Type) := {}.

Instance MyClass_option {A : Type} : MyClass (option A) := {}.

Instance MyClass_option_nat : MyClass (option nat) := {}.
```
</div>
</div>

* No need for Haskell's `FlexibleContexts`. An instance (i.e., a record) can take any other instance (i.e., record) argument. Rocq type classes don't check for cycles, but you can break unexpected cycles by providing explicit parameters and instance names at edit time.

<div class="code-pair">
<div>
```haskell
{-# LANGUAGE FlexibleContexts #-}

class MyClass a

instance (MyClass a) => MyClass (Either a b)

-- requires FlexibleContexts:
instance (MyClass (Maybe a)) => MyClass (Either a b)
```
</div><div>
```ocaml
Class MyClass (A : Type) := {}.

Instance MyClass_sum {A B : Type}
         `{MyClass A} : MyClass (A + B) := {}.

Instance MyClass_sum_option {A B : Type}
         `{MyClass (option A)} : MyClass (A + B) := {}.
```
</div>
</div>

* No need for Haskell's `IncoherentInstances` or `UndecidableInstances`. You can always explicitly pass which instance you want.

<div class="code-pair">
<div>
```haskell
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE IncoherentInstances  #-}

class ToText a where
  toText :: a -> String

-- Very general fallback instance
instance ToText a where
  toText _ = "<unknown>"

-- More specific instance for String
instance ToText String where
  toText s = s
```
</div><div>
```ocaml
From Stdlib Require Import String.
Open Scope string_scope.

Class ToText (A : Type) := { to_text : A -> string }.

(* General “fallback” instance *)
Instance ToText_default {A : Type} : ToText A :=
  {| to_text _ := "<unknown>" |}.

(* More specific instance for string *)
Instance ToText_string : ToText string :=
  {| to_text s := s |}.

(* Uses whatever instance search finds (probably ToText_string). *)
Definition print_auto (s : string) : string :=
  to_text s.

(* Explicitly choose the instance. *)
Definition print_as_unknown (s : string) : string :=
  @to_text string ToText_default s.
```
</div>
</div>

* No need for Haskell's `AllowAmbiguousTypes`. Rocq already lets you to defer the ambiguity check to call sites, and you can resolve them by passing explicit instances.

<div class="code-pair">
<div>
```haskell
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeApplications    #-}

class HasName a where
  name :: String

hello :: forall a. HasName a => String
hello = "Hello, " ++ name @a

data User
instance HasName User where
  name = "User"

greetUser :: String
greetUser = hello @User
```
</div><div>
```ocaml
From Stdlib Require Import String.
Open Scope string_scope.

Class HasName (A : Type) := { name : string }.

Definition hello {A : Type} `{HasName A} : string :=
  "Hello, " ++ name.

Inductive User := mkUser.

Instance HasName_User : HasName User :=
  {| name := "User" |}.

Definition greet_user : string :=
  @hello User HasName_User.
```
</div>
</div>

* No need for Haskell's `TypeSynonymInstances`, since type classes are just record types, and you can define type aliases with simple `Definition`s.
* No need for Haskell's `PartialTypeSignatures`. Rocq already allows omitting parts of types with `_`, and you will get an error if Rocq cannot figure out what the type should be.

(Now, there are a bunch of extensions that don't have a Rocq equivalent, I admit that. `ViewPatterns`, any kind of deriving mechanism or extension, `TypeFamilies` [because [type-case is not allowed in Rocq](https://stackoverflow.com/questions/23220884/why-is-typecase-a-bad-thing), though it is [allowed in Idris 2](https://gist.github.com/edwinb/25cd0449aab932bdf49456d426960fed)], `PatternSynonyms`, etc.)

To cut a long story short, I can't bring myself to learn how to use all these extensions effectively, when I know how simple it is to achieve the same results with dependent types, which enable first-class treatment of type quantification and type classes. I do not want to spend my time learning them when I know that Haskell's type system is like a patchwork of extensions that [try to achieve a fraction of what can be done](https://knowyourmeme.com/memes/look-what-they-need-to-mimic-a-fraction-of-our-power) with dependent types. When you do away with the type/term/module-level distinction, life just becomes simpler, purer, cleaner, and more worth living (thanks [Stephen Fry](https://www.theguardian.com/culture/2015/feb/01/stephen-fry-god-evil-maniac-irish-tv)). Whatever code I write with such a complex system will probably bitrot faster than simple code I will write in these languages. If nothing else, it will be inaccessible to the next developer, or to me, a month after I write it. Whatever paper or blog post I write about such complex code, will be of little value to the programming languages community. Yes, I managed to do this hack this time through blood, sweat, and tears. But why didn't I use a language that didn't actively make my job harder at each step?

I can make the same argument for OCaml's complicated module system with first-class modules, [with which one can do dependent types shenanigans](https://gist.github.com/EduardoRFS/3c9f1c8a92c090db6907e6a2f76963a2). Rocq's module system isn't the best example there but [Agda's module system](https://agda.readthedocs.io/en/latest/language/module-system.html) is certainly worth looking at, as it makes the module/term-level distinction blurrier. There is already work in the literature [[1](https://dl.acm.org/doi/10.1145/44501.45065), [2](https://dl.acm.org/doi/10.1145/1708016.1708028)] about how module-level can be done away with.

I admit, Rocq and Agda will probably never be a mainstream programming language like Haskell (Yes, yes, I know. Haskell is currently [34th on the TIOBE index](https://www.tiobe.com/tiobe-index/), okay?), but some other language may be. These days, [Lean](https://lean-lang.org/) is increasingly looking like it will be the first dependently-typed, somewhat mainstream programming language. But who knows, [maybe Haskell will beat it and have dependent types](https://ghc.serokell.io/dh) soon. (For some definition of "soon.") And yes, I admit, I have the privilege of writing Rocq and C++ for a living these days. (Did you notice how I carefully left out making the same argument for C++ templates? They're even worse in terms of what kind of mischief they allow!) But as long as I am not paid to perform this kind of type or module-level wizardry, I have little interest in getting into it myself.
