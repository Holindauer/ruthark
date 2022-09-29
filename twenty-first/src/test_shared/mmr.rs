use rusty_leveldb::DB;

use crate::util_types::{
    mmr::archival_mmr::ArchivalMmr,
    simple_hasher::{Hashable, Hasher},
};

pub fn get_empty_archival_mmr<H: Hasher>() -> ArchivalMmr<H>
where
    u128: Hashable<<H as Hasher>::T>,
{
    let opt = rusty_leveldb::in_memory();
    let db = DB::open("mydatabase", opt).unwrap();
    ArchivalMmr::new(db)
}

pub fn get_archival_mmr_from_digests<H: Hasher>(digests: Vec<H::Digest>) -> ArchivalMmr<H>
where
    u128: Hashable<<H as Hasher>::T>,
{
    let mut ammr = get_empty_archival_mmr();
    for digest in digests {
        ammr.append_raw(digest);
    }

    ammr
}
