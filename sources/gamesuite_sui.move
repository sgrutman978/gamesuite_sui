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
    use std::string::{String};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    const OneCoinNineDecimals: u64 = 1000000000;

    public struct ProjectCap has key {
         id: UID,
         projectId: address
    }

    public struct Project has key, store {
        id: UID,
        admin: address,
        leaderboards: vector<address>,
        name: String,
        achievements: vector<address>
        // public_key: vector<u8>, // Server's public key
    }

    public struct LeaderboardMetadata has key, store {
        id: UID,
        admin: address,
        project: address,
        public_key: vector<u8>, // Server's public key
        private: bool,
        name: String,
        unit: String,
        sortDesc: bool,
        description: String
    }

    public struct EveryAddressTopScoreLeaderboard has key, store {
        id: UID,
        metadata: LeaderboardMetadata,
        scores: Table<address, u64>,
    }

    // Initialize the leaderboard
    fun init(ctx: &mut TxContext) {

    }

    public entry fun pay_start_game_fee(mut payment: Coin<SUI>, ctx: &mut TxContext) {
        let total_cost = (OneCoinNineDecimals/100)*2;
        assert!(coin::value(&payment) >= total_cost, 0); // Ensure enough payment
        // Split the payment coin into cost and remainder
        let cost = coin::split(&mut payment, total_cost, ctx);
        // Transfer cost to the presale organizer's address
        transfer::public_transfer(cost, @0x8418bb05799666b73c4645aa15e4d1ccae824e1487c01a665f51767826d192b7); // Replace with the address where you want SUI to go
        // Return any remainder to the buyer
        transfer::public_transfer(payment, tx_context::sender(ctx));
    }

    public fun create_project(name: String, payment: Coin<SUI>, ctx: &mut TxContext) : ProjectCap {
        let project = Project {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            leaderboards: vector::empty<address>(),
            name: name,
            achievements: vector::empty()
        };
        let projectId = object::uid_to_address(&project.id);
        let projectCap = ProjectCap {
            id: object::new(ctx),
            projectId: projectId
        };
        pay_start_game_fee(payment, ctx);
        transfer::public_share_object(project);
        projectCap
    }

    public entry fun create_leaderboard(projectCap: &ProjectCap, name: String, unit: String, sortDesc: bool, description: String, project: &mut Project, public_key: vector<u8>, payment: Coin<SUI>, ctx: &mut TxContext){
        let projId = object::uid_to_address(&project.id);
        assert!(&projId == projectCap.projectId, 1);
        pay_start_game_fee(payment, ctx);
        let metadata = LeaderboardMetadata {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            project: projId,
            public_key: public_key, // Set this during deployment
            private: false,
            name: name,
            unit: unit,
            sortDesc: sortDesc,
            description: description
        };
        let leaderboard = EveryAddressTopScoreLeaderboard {
            id: object::new(ctx),
            scores: table::new<address, u64>(ctx),
            metadata: metadata
        };
        let leaderboardId = object::uid_to_address(&leaderboard.id);
        vector::push_back(&mut project.leaderboards, leaderboardId);
        transfer::public_share_object(leaderboard);
    }

    // Submit a score with a signature
    public entry fun submit_score(
        leaderboard: &mut EveryAddressTopScoreLeaderboard,
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
            ed25519::ed25519_verify(&signature, &leaderboard.metadata.public_key, &message),
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
    public fun get_top_scores(leaderboard: &EveryAddressTopScoreLeaderboard): VecMap<address, u64> {
        let scores = vec_map::empty();
        // Logic to sort and return top scores (simplified here)
        scores
    }
}