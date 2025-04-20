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
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::debug;
    use sui::address;

    const OneCoinNineDecimals: u64 = 1000000000;
    const VERSION: u64 = 1;
    const P: vector<u8> = vector[152, 179, 150, 205, 52, 15, 227, 87, 58, 132, 243, 204, 185, 116, 176, 155, 156, 70, 41, 
        215, 210, 71, 237, 214, 158, 71, 156, 98, 106, 31, 94, 176];

    // public struct ProjectRegistryEntry has key, store {
    //      id: UID,
    //      projectAddy: address,
    //      projectCapAddy: address,
    //      projectOwner: address
    // }    

    // public struct ProjectRegistry has key, store {
    //      id: UID,
    //      version: u64,
    //      projects: Table<address, ProjectRegistryEntry>,
    // }  

    public struct ProjectCap has key {
         id: UID,
         name: String,
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
        project_server_keypair_public_key: vector<u8>, // Server's public key
        private: bool,
        name: String,
        unit: String,
        sortDesc: bool,
        description: String
    }

    public struct Testt has key, store {
        id: UID,
        sig: vector<u8>,
        msg: vector<u8>,
        pk: vector<u8>
    }

    public struct EveryAddressTopScoreLeaderboard has key, store {
        id: UID,
        metadata: LeaderboardMetadata,
        scores: Table<address, u64>,
    }

    // Initialize the leaderboard
    fun init(ctx: &mut TxContext) {
        // transfer::public_share_object(ProjectRegistry {
        //     id: object::new(ctx),
        //     version: VERSION,
        //     projects: table::new<address, ProjectRegistryEntry>(ctx)
        // });
        //DO NOT NEED PROJECT REGISTRY, JUST HAVE PROJECT MANAGER GET ALL PROJECTCAP OBJECTS OWNED (each has projectId in it) TO GET LIST OF PROJECTS
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

    public fun create_project(name: String, payment: Coin<SUI>, ctx: &mut TxContext) {
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
            name: name,
            projectId: projectId
        };
        pay_start_game_fee(payment, ctx);
        transfer::public_share_object(project);
        transfer::transfer(projectCap, ctx.sender());
    }

    public entry fun create_leaderboard(projectCap: &ProjectCap, name: String, unit: String, sortDesc: bool, description: String, project: &mut Project, public_key: vector<u8>, payment: Coin<SUI>, private: bool, ctx: &mut TxContext){
        let projId = object::uid_to_address(&project.id);
        assert!(&projId == projectCap.projectId, 1);
        pay_start_game_fee(payment, ctx);
        let metadata = LeaderboardMetadata {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            project: projId,
            project_server_keypair_public_key: public_key, // Set this during deployment
            private: private,
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

    // public fun concat_msg(
    //     addy: String,
    //     num: u64,
    //     separator: &Utf8String
    // ): String {
    //     // Convert u64 to string
    //     let num_str = u64_to_string(num);
        
    //     // Create result string
    //     let result = string::utf8(b"");
    //     string::append(&mut result, *prefix);
    //     string::append(&mut result, *separator);
    //     string::append(&mut result, num_str);
        
    //     result
    // }

//     public fun hex_and_u64_to_string(
//     hex: &String,
//     num: u64,
//     separator: &String
// ): String {
//     let bytes = hex_to_bytes(hex); // From previous question
//     let hex_str = string::utf8(b"0x");
//     let i = 0;
//     while (i < vector::length(&bytes)) {
//         let byte = *vector::borrow(&bytes, i);
//         let high = byte >> 4;
//         let low = byte & 0x0F;
//         string::append_utf8(&mut hex_str, vector[nibble_to_char(high)]);
//         string::append_utf8(&mut hex_str, vector[nibble_to_char(low)]);
//         i = i + 1;
//     };
//     concat_string_and_u64(&hex_str, num, separator)
// }

// fun nibble_to_char(n: u8): u8 {
//     if (n < 10) { 48 + n } else { 87 + n } // 0-9 or a-f
// }


public fun concat_string_and_u64(
        addy: address,
        num: u64,
    ): String {
        // Convert u64 to string
        let num_str = u64_to_string(num);
        let addyStr = address::to_string(addy);
        // Create result string
        let mut result = string::utf8(b"");
        string::append(&mut result, addyStr);
        string::append(&mut result, num_str);
        
        result
    }

    /// Helper function to convert u64 to string.
    fun u64_to_string(num: u64): String {
        if (num == 0) {
            return string::utf8(b"0")
        };
        
        let mut digits = vector::empty<u8>();
        let mut n = num;
        while (n > 0) {
            let digit = (n % 10) as u8;
            vector::push_back(&mut digits, 48 + digit); // ASCII '0' is 48
            n = n / 10;
        };
        
        // Reverse digits to get correct order
        vector::reverse(&mut digits);
        string::utf8(digits)
    }



    // Submit a score with a signature
    public entry fun submit_score(
        leaderboard: &mut EveryAddressTopScoreLeaderboard,
        score: u64,
        // message: vector<u8>,
        // wrapperSig: vector<u8>,
        signature: vector<u8>,
        ctx: &mut TxContext
    ) {
        // Create message hash (same as server)
        let mut message = vector::empty<u8>();
        let player = ctx.sender();
        // let msgStr = 
        // vector::append(&mut message, string_to_bytes(player));
        let messageStr = concat_string_and_u64(ctx.sender(), score);
        vector::append(&mut message, string::into_bytes(messageStr));
    let test = Testt {
        id: object::new(ctx),
        msg: message,
        sig: signature,
        pk: leaderboard.metadata.project_server_keypair_public_key
    };
    transfer::public_share_object(test);

        // std::debug::print(&message);
        // std::debug::print(b');
        // std::debug::print(&signature);


        // let newP = P;

        // assert!(
        //     ed25519::ed25519_verify(&wrapperSig, &newP, &signature),
        //     100, // Invalid signature error code
        // );

        // Verify signature
        // assert!(
        //     ed25519::ed25519_verify(&signature, &leaderboard.metadata.project_server_keypair_public_key, &message),
        //     100, // Invalid signature error code
        // );

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