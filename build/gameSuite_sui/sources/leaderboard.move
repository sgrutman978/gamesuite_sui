// module gamesuite_sui::game {
//     use sui::object::{Self, UID};
//     use sui::transfer;
//     use sui::tx_context::{Self, TxContext};
//     use sui::table::{Self, Table};
//     use sui::ecdsa_k1;
//     use sui::bcs;

//     public struct Leaderboard has key {
//         id: UID,
//         scores: Table<address, u64>,
//         authority_pubkey: vector<u8>,
//     }

//     public entry fun create_leaderboard(authority_pubkey: vector<u8>, ctx: &mut TxContext) {
//         let leaderboard = Leaderboard {
//             id: object::new(ctx),
//             scores: table::new(ctx),
//             authority_pubkey
//         };
//         transfer::transfer(leaderboard, tx_context::sender(ctx));
//     }

//     public entry fun submit_score(
//         leaderboard: &mut Leaderboard,
//         score: u64,
//         signature: vector<u8>,
//         ctx: &mut TxContext
//     ) {
//         let sender = tx_context::sender(ctx);
//         let mut message = vector::empty<u8>();
//         vector::append(&mut message, bcs::to_bytes(&sender));
//         vector::append(&mut message, bcs::to_bytes(&score));

//         let is_valid = ecdsa_k1::secp256k1_verify(&signature, &leaderboard.authority_pubkey, &message, 0);
//         assert!(is_valid, 100);

//         let current_score = if (table::contains(&leaderboard.scores, sender)) {
//             *table::borrow(&leaderboard.scores, sender)
//         } else {
//             0
//         };
//         if (score > current_score) {
//             table::add(&mut leaderboard.scores, sender, score);
//         }
//     }
// }

module gamesuite_sui::leaderboard {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::ed25519; // Sui uses ed25519 for signatures, adjust if secp256k1 is needed
    use sui::vec_map::{Self, VecMap};
    use sui::bcs;

    public struct Leaderboard has key, store {
        id: UID,
        scores: Table<address, u64>,
        admin: address,
        public_key: vector<u8>, // Server's public key
    }

    // Initialize the leaderboard
    fun init(ctx: &mut TxContext) {

    }

    public entry fun create_leaderboard(public_key: vector<u8>, ctx: &mut TxContext){
        let leaderboard = Leaderboard {
            id: object::new(ctx),
            scores: table::new(ctx),
            admin: tx_context::sender(ctx),
            public_key: public_key // Set this during deployment
        };
        transfer::public_share_object(leaderboard);
    }

    // Submit a score with a signature
    public entry fun submit_score(
        leaderboard: &mut Leaderboard,
        player: address,
        score: u64,
        signature: vector<u8>,
        ctx: &mut TxContext
    ) {
        // Create message hash (same as server)
        let mut message = vector::empty<u8>();
        vector::append(&mut message, address_to_bytes(player));
        vector::append(&mut message, u64_to_bytes(score));

        // Verify signature
        assert!(
            ed25519::ed25519_verify(&signature, &leaderboard.public_key, &message),
            100, // Invalid signature error code
        );

        // Update score
        if (table::contains(&leaderboard.scores, player)) {
            let current_score = table::borrow_mut(&mut leaderboard.scores, player);
            if (score > *current_score) {
                *current_score = score;
            }
        } else {
            table::add(&mut leaderboard.scores, player, score);
        }
    }

    // Helper functions
    fun address_to_bytes(addr: address): vector<u8> {
        // Convert address to bytes (implementation depends on Sui's address format)
        // This is a placeholder
        bcs::to_bytes(&addr)
    }

    fun u64_to_bytes(num: u64): vector<u8> {
        bcs::to_bytes(&num)
    }

    // View function to get top scores (optional)
    public fun get_top_scores(leaderboard: &Leaderboard): VecMap<address, u64> {
        let scores = vec_map::empty();
        // Logic to sort and return top scores (simplified here)
        scores
    }
}