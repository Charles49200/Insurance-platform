#[test_only]
module insurance::helpers {
    // === Imports ===
    use std::string::{String};
    use sui::{
        test_scenario::{Self as ts, Scenario},
        clock::{Self}
    };    
    use insurance::insurance::{init_for_testing};
    use insurance::usdc::{init_for_testing_usdc};
    
    // === Constants ===
    const ADMIN: address = @0xA;

    // === Test functions ===
    public fun init_test_helper() : Scenario {
       let mut scenario_val = ts::begin(ADMIN);
       let scenario = &mut scenario_val;
 
       {
        init_for_testing(ts::ctx(scenario));
       };
       {
        init_for_testing_usdc(ts::ctx(scenario));
       };
       scenario_val
    }
}
