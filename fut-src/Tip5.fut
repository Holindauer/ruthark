module Digest = import "Digest"
module BFieldElement = import "BFieldElement"
module shared = import "shared"

type Digest = Digest.Digest
type BFieldElement = BFieldElement.BFieldElement

let STATE_SIZE: i64 = 16
let NUM_SPLIT_AND_LOOKUP: i64 = 4
let RATE: i64 = 10
let NUM_ROUNDS: i64 = 5

-- The lookup table with a high algebraic degree used in the TIP-5 permutation. To verify its
-- correctness, see the test “lookup_table_is_correct.”
let LOOKUP_TABLE: [256]u8 = [
    0u8, 7u8, 26u8, 63u8, 124u8, 215u8, 85u8, 254u8, 214u8, 228u8, 45u8, 185u8, 140u8, 173u8, 33u8, 240u8,
    29u8, 177u8, 176u8, 32u8, 8u8, 110u8, 87u8, 202u8, 204u8, 99u8, 150u8, 106u8, 230u8, 14u8, 235u8, 128u8,
    213u8, 239u8, 212u8, 138u8, 23u8, 130u8, 208u8, 6u8, 44u8, 71u8, 93u8, 116u8, 146u8, 189u8, 251u8, 81u8,
    199u8, 97u8, 38u8, 28u8, 73u8, 179u8, 95u8, 84u8, 152u8, 48u8, 35u8, 119u8, 49u8, 88u8, 242u8, 3u8,
    148u8, 169u8, 72u8, 120u8, 62u8, 161u8, 166u8, 83u8, 175u8, 191u8, 137u8, 19u8, 100u8, 129u8, 112u8, 55u8,
    221u8, 102u8, 218u8, 61u8, 151u8, 237u8, 68u8, 164u8, 17u8, 147u8, 46u8, 234u8, 203u8, 216u8, 22u8, 141u8,
    65u8, 57u8, 123u8, 12u8, 244u8, 54u8, 219u8, 231u8, 96u8, 77u8, 180u8, 154u8, 5u8, 253u8, 133u8, 165u8,
    98u8, 195u8, 205u8, 134u8, 245u8, 30u8, 9u8, 188u8, 59u8, 142u8, 186u8, 197u8, 181u8, 144u8, 92u8, 31u8,
    224u8, 163u8, 111u8, 74u8, 58u8, 69u8, 113u8, 196u8, 67u8, 246u8, 225u8, 10u8, 121u8, 50u8, 60u8, 157u8,
    90u8, 122u8, 2u8, 250u8, 101u8, 75u8, 178u8, 159u8, 24u8, 36u8, 201u8, 11u8, 243u8, 132u8, 198u8, 190u8,
    114u8, 233u8, 39u8, 52u8, 21u8, 209u8, 108u8, 238u8, 91u8, 187u8, 18u8, 104u8, 194u8, 37u8, 153u8, 34u8,
    200u8, 143u8, 126u8, 155u8, 236u8, 118u8, 64u8, 80u8, 172u8, 89u8, 94u8, 193u8, 135u8, 183u8, 86u8, 107u8,
    252u8, 13u8, 167u8, 206u8, 136u8, 220u8, 207u8, 103u8, 171u8, 160u8, 76u8, 182u8, 227u8, 217u8, 158u8, 56u8,
    174u8, 4u8, 66u8, 109u8, 139u8, 162u8, 184u8, 211u8, 249u8, 47u8, 125u8, 232u8, 117u8, 43u8, 16u8, 42u8,
    127u8, 20u8, 241u8, 25u8, 149u8, 105u8, 156u8, 51u8, 53u8, 168u8, 145u8, 247u8, 223u8, 79u8, 78u8, 226u8,
    15u8, 222u8, 82u8, 115u8, 70u8, 210u8, 27u8, 41u8, 1u8, 170u8, 40u8, 131u8, 192u8, 229u8, 248u8, 255u8
]

-- TODO: Is it more performant to use `from_raw_u64` here? In other words: Will Futhark
-- do the appropriate constant-folding here?
def ROUND_CONSTANTS: [NUM_ROUNDS * STATE_SIZE]BFieldElement =
  map BFieldElement.new
    [
      13630775303355457758u64,
      16896927574093233874,
      10379449653650130495,
      1965408364413093495,
      15232538947090185111,
      15892634398091747074,
      3989134140024871768,
      2851411912127730865,
      8709136439293758776,
      3694858669662939734,
      12692440244315327141,
      10722316166358076749,
      12745429320441639448,
      17932424223723990421,
      7558102534867937463,
      15551047435855531404,
      17532528648579384106,
      5216785850422679555,
      15418071332095031847,
      11921929762955146258,
      9738718993677019874,
      3464580399432997147,
      13408434769117164050,
      264428218649616431,
      4436247869008081381,
      4063129435850804221,
      2865073155741120117,
      5749834437609765994,
      6804196764189408435,
      17060469201292988508,
      9475383556737206708,
      12876344085611465020,
      13835756199368269249,
      1648753455944344172,
      9836124473569258483,
      12867641597107932229,
      11254152636692960595,
      16550832737139861108,
      11861573970480733262,
      1256660473588673495,
      13879506000676455136,
      10564103842682358721,
      16142842524796397521,
      3287098591948630584,
      685911471061284805,
      5285298776918878023,
      18310953571768047354,
      3142266350630002035,
      549990724933663297,
      4901984846118077401,
      11458643033696775769,
      8706785264119212710,
      12521758138015724072,
      11877914062416978196,
      11333318251134523752,
      3933899631278608623,
      16635128972021157924,
      10291337173108950450,
      4142107155024199350,
      16973934533787743537,
      11068111539125175221,
      17546769694830203606,
      5315217744825068993,
      4609594252909613081,
      3350107164315270407,
      17715942834299349177,
      9600609149219873996,
      12894357635820003949,
      4597649658040514631,
      7735563950920491847,
      1663379455870887181,
      13889298103638829706,
      7375530351220884434,
      3502022433285269151,
      9231805330431056952,
      9252272755288523725,
      10014268662326746219,
      15565031632950843234,
      1209725273521819323,
      6024642864597845108
    ] :> [NUM_ROUNDS * STATE_SIZE]BFieldElement

type Domain = #variable_length | #fixed_length

type Tip5 = { state: [STATE_SIZE]BFieldElement }

def new
  (domain: Domain)
  : Tip5 =
  match domain
  case #variable_length ->
    { state = replicate STATE_SIZE BFieldElement.zero }
  case #fixed_length ->
    { state
     = (replicate RATE BFieldElement.zero)
      ++ replicate (STATE_SIZE - RATE) BFieldElement.one
      :> [STATE_SIZE]BFieldElement }

-- used in lookup table verification
def offset_fermat_cube_map (x: u16): u16 =
  let xx = u64.u16(x) + 1 
  let xxx = xx * xx * xx     
  let result = (xxx + 256) % 257
  in u16.u64(result)   

def round
  (round_index: i64)
  (self: Tip5)
  : Tip5 =
  -- TODO: Call `sbox_layer` and `mds_generate`

  let rounds_rc_indices = map ((+) (round_index * STATE_SIZE)) (iota STATE_SIZE)
  let rounds_rc = shared.gather ROUND_CONSTANTS rounds_rc_indices :> [STATE_SIZE]BFieldElement
  in {state = map2 (BFieldElement.+^) self.state rounds_rc }


def permutation
 (self: Tip5)
 : Tip5 =
 loop sponge = self for i < NUM_ROUNDS do
  round i sponge

def hash_pair
 (left: Digest)
 (right: Digest)
 : Digest =
--  let sponge_state = replicate STATE_SIZE BFieldElement.zero
  let sponge_state =
    left.0
    ++ right.0
    ++ replicate (STATE_SIZE - RATE) BFieldElement.one
    :> [STATE_SIZE]BFieldElement
  let sponge_state: Tip5 = { state = sponge_state }
  let sponge_state = permutation sponge_state

  -- TODO: Fix return value
  in left
--  let sponge_state = scatter (sponge.state) (iota DIGEST_LENGTH) left.0

 -- set first DIGEST_LENGTH words of state from left values
 -- set next DIGEST_LENGTH words of state from right values


-- ==
-- entry: lookup_table_is_correct
-- random input { }
-- output { true }
entry lookup_table_is_correct : bool =
  let generated_table : [256]u8 = 
    map (\i -> u8.u16(offset_fermat_cube_map(u16.i64(i)))) (iota 256)
  in reduce (&&) true (map2 (==) LOOKUP_TABLE generated_table)