#[test_only]
module insurance::test_insurance {
    // === Imports ===
    use sui::{
        test_scenario::{Self as ts, next_tx},
        coin::{Self},
        sui::SUI,
        test_utils::{assert_eq},
        kiosk::{Self},
        transfer_policy::{TransferPolicy}
    };
    use std::string::{Self, String};

    use insurance::insurance::{Self};
    use insurance::helpers::init_test_helper;

    // === Constants ===
    const ADMIN: address = @0xA;
    const TEST_ADDRESS1: address = @0xB;
    // const TEST_ADDRESS2: address = @0xC;

    // === Test functions ===

    #[test]
    public fun test_insurance() {

        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;
        
           // User has to buy water_cooler from cooler_factory share object. 
        next_tx(scenario, TEST_ADDRESS1);
        {


          

         
        };
        ts::end(scenario_test);
    }
}   
