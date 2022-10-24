module BFieldElement = import "BFieldElement"

type BFieldElement = BFieldElement.BFieldElement
-- a*x^2 + b*x + c:  (c            , b            , a            )
type XFieldElement = (BFieldElement, BFieldElement, BFieldElement)

type ZFieldElement = [3]BFieldElement -- Probably better implemented in a separate lib

def new (c: BFieldElement) (b: BFieldElement) (a: BFieldElement) : XFieldElement =
  let canonicalize = BFieldElement.canonicalize
  in (canonicalize c, canonicalize b, canonicalize a)

def new_u64 (coeffs: [3]u64) : XFieldElement = new coeffs[0] coeffs[1] coeffs[2]

def new_const (element: BFieldElement) : XFieldElement = new element BFieldElement.zero BFieldElement.zero

def from_u64 (number: u64) : XFieldElement = BFieldElement.new number |> new_const

def tripple2array (c, b, a) : [3]u64 = [c, b, a]
def array2tripple (cba: [3]u64) : XFieldElement = new cba[0] cba[1] cba[2]

def canonicalize ((c, b, a) : XFieldElement) : XFieldElement =
  ( BFieldElement.canonicalize c
  , BFieldElement.canonicalize b
  , BFieldElement.canonicalize a
  )

def eq (a : XFieldElement) (b : XFieldElement) : bool =
  (canonicalize a) == (canonicalize b)

def zero : XFieldElement = new_const BFieldElement.zero
def one : XFieldElement = new_const BFieldElement.one
-- def two : XFieldElement = new_const (BFieldElement.add BFieldElement.one BFieldElement.one)
-- def default : XFieldElement = one

def is_zero ((c, b, a) : XFieldElement) : bool =
  let zero = BFieldElement.zero
  in zero == BFieldElement.canonicalize c
  && zero == BFieldElement.canonicalize b
  && zero == BFieldElement.canonicalize a

def is_one ((c, b, a) : XFieldElement) : bool =
  let zero = BFieldElement.zero
  let one = BFieldElement.one
  in one == BFieldElement.canonicalize c
  && zero == BFieldElement.canonicalize b
  && zero == BFieldElement.canonicalize a

def add ((c0, b0, a0) : XFieldElement) ((c1, b1, a1) : XFieldElement) : XFieldElement =
  ( (BFieldElement.add c0 c1)
  , (BFieldElement.add b0 b1)
  , (BFieldElement.add a0 a1)
  )

def neg ((c, b, a) : XFieldElement) : XFieldElement =
  ( BFieldElement.neg c
  , BFieldElement.neg b
  , BFieldElement.neg a
  )

def minus_one : XFieldElement = neg one

def from_i32 (number: i32) : XFieldElement =
  if number >= 0
  then u64.i32 number |> BFieldElement.new |> new_const
  else u64.i32 (-number) |> BFieldElement.new |> new_const |> neg

def sub (a: XFieldElement) (b: XFieldElement) : XFieldElement =
  add a (neg b)

-- TODO: Requires Polynomial.divide and BFieldElement.inverse
-- This should not be needed at all.
-- def inverse (_a : XFieldElement) : XFieldElement =
-- let no = no
--  in no

def xfexfemul ((c0, b0, a0) : XFieldElement) ((c1, b1, a1) : XFieldElement) : XFieldElement =
--  let canonicalizeB = BFieldElement.canonicalize
--  let mul = \x y -> canonicalizeB (BFieldElement.mul x y)
--  let add = \x y -> canonicalizeB (BFieldElement.add x y)
--  let sub = \x y -> canonicalizeB (BFieldElement.sub x y)
  let mul = BFieldElement.mul
  let add = BFieldElement.add
  let sub = BFieldElement.sub
-- Special casing for LHS = 0 + (a : BFieldElement) or RHS = 0 + (b: BFieldElement) is
-- likely not a good idea for GPU code.  But run benchmarks.
-- Note that `sub` is likely more expensive than `add`.
  in
-- ( c0 * c1 - a0 * b1 - b0 * a1                      -- * x^0
-- ( c0 * c1 - (a0 * b1 + b0 * a1)                    -- * x^0
-- canonicalize
-- alternatively: ( sub (mul c0 c1) (add (mul a0 b1) (mul b0 a1))
    ( sub
      (mul c0 c1)
      (add
        (mul a0 b1)
        (mul b0 a1))
-- , b0 * c1 + c0 * b1 - a0 * a1 + a0 * b1 + b0 * a1  -- * x^1
-- , b0 * c1 + c0 * b1 + a0 * b1 + b0 * a1 - a0 * a1
-- alternatively: , sub (add (add (add (mul b0 c1) (mul c0 b1)) (mul a0 b1)) (mul b0 a1)) (mul a0 a1)
  , sub
      (add
        (add
          (add
            (mul b0 c1)
            (mul c0 b1))
          (mul a0 b1))
        (mul b0 a1))
      (mul a0 a1)
 -- , a0 * c1 + b0 * b1 + c0 * a1 + a0 * a1           -- * x^2
-- alternatively, add (add (add (mul a0 c1) (mul b0 b1)) (mul c0 a1)) (mul a0 a1)
  , add
      (add
        (add
          (mul a0 c1)
          (mul b0 b1))
        (mul c0 a1))
      (mul a0 a1)
  )

def (x: BFieldElement) |-| (y: BFieldElement) = BFieldElement.sub x y
def (x: BFieldElement) |+| (y: BFieldElement) = BFieldElement.add x y
def (x: BFieldElement) |*| (y: BFieldElement) = BFieldElement.mul x y

def xfebfemul ((c0, b0, a0) : XFieldElement) ((c1, _b1, _a1) : XFieldElement) : XFieldElement =
                (c0 |*| c1, b0 |*| c1, a0 |*| c1)

def mul ((c0, b0, a0) : XFieldElement) ((c1, b1, a1) : XFieldElement) : XFieldElement =
          if (a1 == 0) && (b1 == 0) then xfebfemul (c0, b0, a0) (c1, b1, a1)
          else xfexfemul (c0, b0, a0) (c1, b1, a1)

def mul_bfe ((c0, b0, a0) : XFieldElement) (bfe : BFieldElement) : XFieldElement =
  ( BFieldElement.mul c0 bfe
  , BFieldElement.mul b0 bfe
  , BFieldElement.mul a0 bfe
  )


-- def div (a: XFieldElement) (b: XFieldElement) : XFieldElement =
--  mul a (inverse b)

-- def rem ((c0, b0, a0) : XFieldElement) ((c1, b1, a1) : XFieldElement) : XFieldElement = one
-- Not supported https://futhark-book.readthedocs.io/en/latest/language.html#parametric-polymorphism
-- def mod_pow 't (element : XFieldElement) (exponent: t) : XFieldElement =

def mod_pow_u64 (element : XFieldElement) (exponent: u64) : XFieldElement =
  let (_, _, result) = loop (x, i, result) = (element, exponent, one) while i > 0 do
      if i % 2 == 1
      then (mul x x, i>>1, mul x result)
      else (mul x x, i>>1, result)
  in result

def mod_pow_u32 (element : XFieldElement) (exponent: u32) : XFieldElement =
  let (_, _, result) = loop (x, i, result) = (element, exponent, one) while i > 0 do
      if i % 2 == 1
      then (mul x x, i>>1, mul x result)
      else (mul x x, i>>1, result)
   in result

def mod_pow_u8 (element : XFieldElement) (exponent: u8) : XFieldElement =
  let (_, _, result) = loop (x, i, result) = (element, exponent, one) while i > 0 do
      if i % 2 == 1
      then (mul x x, i>>1, mul x result)
      else (mul x x, i>>1, result)
   in result

-- Segmented scan with XFieldElement.add
-- Benchmark against version from fut library
def segmented_scan_add [t] (flags : [t]bool) (vals : [t]XFieldElement) : []XFieldElement =
  let pairs = scan ( \(v1,f1) (v2,f2) ->
                       let f = f1 || f2
                       let v = if f2 then v2 else add v1 v2
                       in (v,f) ) (zero, false) (zip vals flags)
  let (res, _) = unzip pairs
   in res
