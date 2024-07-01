#[test_only]
module insurance::helpers {
    // === Imports ===
    use std::string::{String};
    use sui::{
        test_scenario::{Self as ts, Scenario},
        clock::{Self}
    };    
    use insurance::insurance::{init_for_testing};

    // === Constants ===
    const ADMIN: address = @0xA;

    // === Test functions ===
    public fun init_test_helper() : Scenario {
       let mut scenario_val = ts::begin(ADMIN);
       let scenario = &mut scenario_val;
 
       {
        init_for_testing(ts::ctx(scenario));
        let clock = clock::create_for_testing(scenario.ctx());
        clock::share_for_testing(clock);
       };
       scenario_val
    }
}
