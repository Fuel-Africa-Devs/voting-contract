contract;
use std::{
    auth::msg_sender,
    block::timestamp,
    constants::ZERO_B256,
    hash::Hash,
    identity::Identity,
    string::String,
};
use std::storage::storage_vec::*;

struct Proposals {
    id: u64,
    vote_starts: u64,
    vote_ends: u64,
}
struct Candidate {
    user_name: [u8; 32],
    user_address: Identity,
}

struct VoteScore {
    user: Candidate,
    score: u64,
}

storage {
    counter_id: u64 = 0,
    is_voted: StorageMap<Identity, bool> = StorageMap {},
    id_list_of_candidates: StorageMap<u64, StorageVec<Candidate>> = StorageMap {},
    id_to_proposal: StorageMap<u64, Proposals> = StorageMap {},
    id_to_candidate: StorageMap<Identity, VoteScore> = StorageMap {},
}

abi MyContract {
    #[storage(read, write)]
    fn create_proposal(
        candidiate_info: Vec<Candidate>,
        vote_starts: u64,
        vote_ends: u64,
    ) -> u64;

    #[storage(read, write)]
    fn vote(
        vote_id: u64,
        candidate_name: [u8; 32],
        candidate_address: Identity,
    );

    #[storage(read)]
    fn get_winner(vote_id: u64) -> Candidate;
}

impl MyContract for Contract {
    #[storage(read, write)]
    fn create_proposal(
        candidiate_info: Vec<Candidate>,
        vote_starts: u64,
        vote_ends: u64,
    ) -> u64 {
        let current_count: u64 = storage.counter_id.read();
        let new_vote_info = Proposals {
            id: current_count,
            vote_starts,
            vote_ends,
        };
        storage.id_to_proposal.insert(current_count, new_vote_info);
        let _ = storage.id_list_of_candidates.try_insert(current_count, StorageVec {});

        for each_candidate in candidiate_info.iter() {
        storage.id_list_of_candidates.get(current_count).push(each_candidate);

            let new_candidate_score : VoteScore=  VoteScore{
                 user: each_candidate,
                score: 0,
            };    
            let _ =storage.id_to_candidate.try_insert(each_candidate.user_address,new_candidate_score);  
        }

        storage.counter_id.write(current_count + 1);
        current_count
    }

    #[storage(read, write)]
    fn vote(
        vote_id: u64,
        candidate_name: [u8; 32],
        candidate_address: Identity,
    ) {
        let vote_begins = storage.id_to_proposal.get(vote_id).try_read().unwrap().vote_starts;
        let vote_ends = storage.id_to_proposal.get(vote_id).try_read().unwrap().vote_ends;
        let user_voted: bool = storage.is_voted.get(msg_sender().unwrap()).try_read().unwrap();
        assert(timestamp() > vote_begins && timestamp() < vote_ends);
        assert(!user_voted);
        let candidatae_info: Candidate = Candidate {
            user_name: candidate_name,
            user_address: candidate_address,
        };
        let info = storage.id_to_candidate.get(candidate_address).try_read().unwrap().user;
        assert(info.user_address == candidate_address);
        let prev_vote_count = storage.id_to_candidate.get(candidate_address).try_read().unwrap().score;
        let new_vote_info = VoteScore {
            user: candidatae_info,
            score: prev_vote_count + 1,
        };

        storage
            .id_to_candidate
            .insert(candidate_address, new_vote_info);

        storage.is_voted.insert(msg_sender().unwrap(), true);
    }

    #[storage(read)]
    fn get_winner(vote_id: u64) -> Candidate {
        // go through all the candidates and get the higest score per id...
        // ensure voting has ended... 
        let vote_ends = storage.id_to_proposal.get(vote_id).try_read().unwrap().vote_ends;
        assert(timestamp() > vote_ends);

        let all_candidiate_info = storage.id_list_of_candidates.get(vote_id);
        let mut highest_score = 0;
        let mut winner = Candidate {
            user_name: [0; 32],
            user_address: Identity::Address(Address::from(ZERO_B256)),
        };
   
     let mut i = 0;
        while i < all_candidiate_info.len() {
            let each_candidate = all_candidiate_info.get(i).unwrap().read();
            let score = storage.id_to_candidate.get(each_candidate.user_address).try_read().unwrap().score;
            if score > highest_score {
                highest_score = score;
                winner = each_candidate;
            }
            i += 1;
        }

        winner
    }
}

//  decentralized voting contrat...  
// Create proposals -> what to vote on... 
// Cast votes
// Determine winners
