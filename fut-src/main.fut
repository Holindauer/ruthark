-- Math foundation
module BFieldElement = import "BFieldElement"
module XFieldElement = import "XFieldElement"
module bfe_poly = import "bfe_poly"
module xfe_poly = import "xfe_poly"
module ArithmeticDomain = import "arithmetic_domain"
module master_base_table_module = import "master_base_table"
module master_ext_table = import "master_ext_table"
module SpongeWithPendingAbsorb = import "sponge_with_pending_absorb"
module MerkleTree = import "MerkleTree"
module Digest = import "Digest"
module Tip5 = import "Tip5"
module ProofStream = import "proof_stream"
module proof = import "proof" 

type XFieldElement = XFieldElement.XFieldElement
type BFieldElement = BFieldElement.BFieldElement
type BfePolynomial [n] = bfe_poly.BfePolynomial [n]
type XfePolynomial [n] = xfe_poly.XfePolynomial [n]
type ArithmeticDomain = ArithmeticDomain.ArithmeticDomain
type~ MasterBaseTable [rows] [cols] = master_base_table_module.MasterBaseTable [rows] [cols]
type MasterExtTable [rows] [cols] = master_ext_table.MasterExtTable [rows] [cols]
type Digest = Digest.Digest
type~ MerkleTree = MerkleTree.MerkleTree
type SpongeWithPendingAbsorb = SpongeWithPendingAbsorb.SpongeWithPendingAbsorb
type~ ProofStream = ProofStream.ProofStream

let NUM_COLUMNS = master_ext_table.NUM_COLUMNS

let fri_domain_offset = BFieldElement.new 7

-- test rust-futhark interop
entry test_gpu_kernel (number: u64) : u64 = number + 1

-- converts [][][3]u64 to [][]XFieldElement 
entry test_array_conversion_does_not_change_data (u64_table: [][][3]u64) : [][][3]u64 = 
    -- [][][3]u64 -> [][]XFieldElement
    let xfe_table : [][]XFieldElement = 
      map (map (\x -> XFieldElement.new_from_raw_u64_arr x)) u64_table
    -- [][]XFieldElement --> [][][3]u64
    in map (map (\x -> XFieldElement.to_raw_u64_arr x)) xfe_table

-- low degree extension of master base table
entry lde_master_base_table_kernel
  (randomized_trace_domain_offset: u64) 
  (randomized_trace_domain_gen: u64) 
  (randomized_trace_domain_len: i64)
  (randomized_trace_table: [][]u64)
  : [][]u64 = 

    -- [][]u64 -> [][]BFieldElement
    let randomized_trace_table : [][]BFieldElement = 
      map (map (\x -> BFieldElement.from_raw_u64 x)) randomized_trace_table

    -- to arithmetic domain
    let randomized_trace_domain: ArithmeticDomain = {
      offset = { 0 = randomized_trace_domain_offset} :> BFieldElement,
      generator = {0 = randomized_trace_domain_gen } :> BFieldElement,
      len = randomized_trace_domain_len
    }

    -- package table
    let master_base_table =  {   
        randomized_trace_domain,
        randomized_trace_table
    } :> MasterBaseTable [] []

    -- run lde
    let interpolant_polynomials: []BfePolynomial[] =
      master_base_table_module.low_degree_extend_all_columns master_base_table


    let poly_coeff_values: [][]u64 = 
      map (\poly -> map BFieldElement.to_raw_u64 poly.coefficients) interpolant_polynomials    

    in poly_coeff_values

-- merklelize master base table
entry master_base_table_merkle_tree_kernel
  (interpolants: [][]u64)
  (fri_domain_offset: u64) (fri_domain_gen: u64) (fri_domain_len: i64)
  : [][]u64 =  

    -- correct data format
    let interpolants: []BfePolynomial[] = 
      map (map BFieldElement.from_raw_u64) interpolants  
      |> map bfe_poly.new 

    let fri_domain = ArithmeticDomain.new 
      (BFieldElement.from_raw_u64 fri_domain_offset) 
      (BFieldElement.from_raw_u64 fri_domain_gen) 
      fri_domain_len

    -- hash all fri domain rows JIT
    let hashed_rows: []Digest = 
      master_base_table_module.hash_all_fri_domain_rows_just_in_time interpolants fri_domain

    -- compute merkle tree
    let merkle_tree: MerkleTree = MerkleTree.from_digests hashed_rows
    in map (\x -> map BFieldElement.to_raw_u64 x.0) merkle_tree.nodes

-- Note, the u64 values passed into this kernel are raw coefficient values for Xfe/Bfe/...
-- This is not that same as what is returned by .value()/BFieldElement.value() 
entry lde_master_ext_table_kernel  
  (num_trace_randomizers: i64)
  (trace_domain_offset: u64) (trace_domain_gen: u64) (trace_domain_len: i64) -- "ArithmeticDomain"
  (randomized_trace_domain_offset: u64) (randomized_trace_domain_gen: u64) (randomized_trace_domain_len: i64)
  (quotient_domain_offset: u64) (quotient_domain_gen: u64) (quotient_domain_len: i64)
  (fri_domain_offset: u64) (fri_domain_gen: u64) (fri_domain_len:i64)
  (randomized_trace_table: [][][3]u64) -- 2d Xfe array
  : [][][3]u64 = -- encoded version of [NUM_COLUMNS][rows]XfePolynomial[] 

    -- package into master ext table
    let master_extension_table: MasterExtTable [][] = master_ext_table.new
      num_trace_randomizers
      trace_domain_offset trace_domain_gen trace_domain_len
      randomized_trace_domain_offset randomized_trace_domain_gen randomized_trace_domain_len 
      quotient_domain_offset quotient_domain_gen quotient_domain_len
      fri_domain_offset fri_domain_gen fri_domain_len
      randomized_trace_table

    -- interpolate on larger domain
    let interpolant_polynomials =
      master_ext_table.low_degree_extend_all_columns master_extension_table

    -- conversion for return into rust program
    -- NOTE: the rows of the major axis each contain a polynomial represented
    -- as encoded coefficients of [][3]u64
    let poly_coeff_values: [][][3]u64 = 
      map 
      (\poly -> map XFieldElement.to_raw_u64_arr poly.coefficients)
      interpolant_polynomials    

    in poly_coeff_values

-- -- NOTE: this entry point assumes it is receicing the Array_u64_3d that was output
-- -- by the call of lde_master_ext_table_kernel above
entry master_ext_table_merkle_tree_kernel
  (interpolants: [][][3]u64)
  (fri_domain_offset: u64) (fri_domain_gen: u64) (fri_domain_len: i64)
  : [][]u64 =  

    -- correct data format
    let interpolants: []XfePolynomial[] = 
      map (map XFieldElement.new_from_raw_u64_arr) interpolants  
      |> map xfe_poly.new 

    let fri_domain = ArithmeticDomain.new 
      (BFieldElement.from_raw_u64 fri_domain_offset) 
      (BFieldElement.from_raw_u64 fri_domain_gen) 
      fri_domain_len

    -- hash all fri domain rows JIT
    let hashed_rows: []Digest = 
      master_ext_table.hash_all_fri_domain_rows_just_in_time interpolants fri_domain

    -- compute merkle tree
    let merkle_tree: MerkleTree = MerkleTree.from_digests hashed_rows
    in map (\x -> map BFieldElement.to_raw_u64 x.0) merkle_tree.nodes

-- hashes a variable length input of raw bfe u64 internal values
entry tip5_hash_varlen_kernel (input: []u64) : []u64 =
  map BFieldElement.from_raw_u64 input |> Tip5.hash_varlen |> \x -> map BFieldElement.to_raw_u64 x.0

-- tip5 sponge w/ pending absorb (for testing purposes)
entry sponge_with_pending_absorb_kernel (input: []u64) : []u64 = 
  let input: []BFieldElement = map BFieldElement.from_raw_u64 input
 
  let sponge = SpongeWithPendingAbsorb.new 
  let absorbed = SpongeWithPendingAbsorb.absorb sponge input
  let finalized: Digest = SpongeWithPendingAbsorb.finalize absorbed
  
  in map BFieldElement.to_raw_u64 finalized.0


-- computes merkle tree from set of digests, returns raw u64 node digest bfe values
entry from_digest_tip5_kernel (input: [][]u64) : [][Digest.DIGEST_LENGTH]u64 = 
  let input: []Digest = map (\x -> map BFieldElement.from_raw_u64 x) input
                        |> map (take Digest.DIGEST_LENGTH)
                        |> map (\x -> { 0 = x}) 
  let merkle_tree = MerkleTree.from_digests input 
  let nodes = map (\x -> map BFieldElement.to_raw_u64 x.0) merkle_tree.nodes
  in nodes

-- computes authentication structure for merkle tree
entry authentication_structure_kernel(nodes: [][]u64) (leaf_indices: []i64) : [][]u64 = 
  let merkle_tree: MerkleTree = map (\x -> map BFieldElement.from_raw_u64 x) nodes
                        |> map (take Digest.DIGEST_LENGTH)
                        |> map (\x -> { 0 = x}) 
                        |>  \x -> {nodes = x} :> MerkleTree
  let auth_structure = MerkleTree.authentication_structure merkle_tree leaf_indices 
  in map (\x -> map BFieldElement.to_raw_u64 x.0) auth_structure

-- compures fri domain rows using interpolation polynomials from lde of the 
-- MasterExtTable, then computes the hash of each w/ SpongeWithPendingAbsorb
-- (for testing purposes)
entry hash_all_fri_domain_rows_just_in_time_kernel 
  (interpolants: [][][3]u64)
  (fri_domain_offset: u64) (fri_domain_gen: u64) (fri_domain_len:i64) 
  : [][]u64 = 
    -- correct data format
    let interpolants: []XfePolynomial[] = 
      map (map XFieldElement.new_from_raw_u64_arr) interpolants  
      |> map xfe_poly.new 

    let fri_domain = ArithmeticDomain.new 
      (BFieldElement.from_raw_u64 fri_domain_offset) 
      (BFieldElement.from_raw_u64 fri_domain_gen) 
      fri_domain_len

    -- hash all fri domain rows JIT
    let result: []Digest = 
      master_ext_table.hash_all_fri_domain_rows_just_in_time interpolants fri_domain

    in map (\x -> map BFieldElement.to_raw_u64 x.0) result


-- instantiates proof stream, alters_fiat_shamir state with claim
entry create_proof_stream_and_alter_fiat_shamir_state_with_claim_kernel 
  (encoded_claim: []u64): []u64 =

  let encoded_claim' = map BFieldElement.from_raw_u64 encoded_claim

  let proof_stream = ProofStream.new
  let proof_stream' = ProofStream.alter_fiat_shamir_state_with proof_stream encoded_claim'

  -- returns sponge state for now, since other fields remain the default
  in map BFieldElement.to_raw_u64 proof_stream'.sponge.state
