-- Constant-time log2 (depending on architecture, I guess)
def ilog2 (n: i64) : i64 = i64.i32 (63 - i64.clz n)

def is_power_of_2 (n: i64) : bool = n > 0 && ((n - 1) & n == 0)

def eq_arr 'a [n] [m] (eq: a -> a -> bool) (a: [n]a) (b: [m]a) : bool =
  n == m && and (map2 eq a (b :> [n]a))

def eq_arr_2d 'a [n1] [n2] [m1] [m2]
              (eq: a -> a -> bool) (a: [n1][n2]a) (b: [m1][m2]a) : bool =
  n1 == m1 && n2 == m2 && eq_arr (eq_arr eq) a (b :> [n1][n2]a)

def gather 'a (xs: []a) (is: []i64): []a =
  map (\i -> xs[i]) is

-- Convert unsigned 64-bit integer to an array of 8 bytes (little-endian)
def u64_to_bytes_le (x: u64): [8]u8 =
  let byte0 = u8.u64(x >> 0)
  let byte1 = u8.u64(x >> 8)
  let byte2 = u8.u64(x >> 16)
  let byte3 = u8.u64(x >> 24)
  let byte4 = u8.u64(x >> 32)
  let byte5 = u8.u64(x >> 40)
  let byte6 = u8.u64(x >> 48)
  let byte7 = u8.u64(x >> 56)
  in [byte0, byte1, byte2, byte3, byte4, byte5, byte6, byte7]

-- Convert an array of 8 bytes (little-endian) to a 64-bit unsigned integer 
def bytes_le_to_u64 (x: [8]u8 ): u64=
  let byte0 = u64.u8(x[0]) << 0
  let byte1 = u64.u8(x[1]) << 8
  let byte2 = u64.u8(x[2]) << 16
  let byte3 = u64.u8(x[3]) << 24
  let byte4 = u64.u8(x[4]) << 32
  let byte5 = u64.u8(x[5]) << 40
  let byte6 = u64.u8(x[6]) << 48
  let byte7 = u64.u8(x[7]) << 56
  in byte0 + byte1 + byte2 + byte3 + byte4 + byte5 + byte6 + byte7

-- next multiple of m greater than or equal to x
let next_multiple_of (x: i64) (m: i64) : i64 =
  if m <= 0 then
    0
  else if x >= 0 then
    ((x + m - 1) // m) * m
  else
    let base_multiple = ((-x + m - 1) // m) * m
    in -base_multiple

-- ==
-- entry: test_u64_to_bytes_le
-- input  { 0u64 }
-- output { [0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8] }
-- input  { 89203u64 }
-- output { [115u8, 92u8, 1u8, 0u8, 0u8, 0u8, 0u8, 0u8] }
-- input  { 9303949u64 }
-- output { [141u8, 247u8, 141u8, 0u8, 0u8, 0u8, 0u8, 0u8] }
entry test_u64_to_bytes_le (x: u64): [8]u8 =
  u64_to_bytes_le(x)

-- ==
-- entry: test_bytes_to_u64
-- input  { [0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8] }
-- output { 0u64 }
-- input  { [115u8, 92u8, 1u8, 0u8, 0u8, 0u8, 0u8, 0u8] }
-- output { 89203u64 }
-- input  { [141u8, 247u8, 141u8, 0u8, 0u8, 0u8, 0u8, 0u8] }
-- output { 9303949u64 }
entry test_bytes_to_u64 (x: [8]u8): u64 =
  bytes_le_to_u64(x)

-- ==
-- entry: test_next_multiple_of
-- input  { 0i64 1i64 }
-- output { 0i64 }
-- input  { 1i64 1i64 }
-- output { 1i64 }
-- input  { 7i64 4i64 }
-- output { 8i64 }
-- input  { 7i64 0i64 }
-- output { 0i64 }
entry test_next_multiple_of (x: i64) (m: i64): i64 =
  next_multiple_of x m