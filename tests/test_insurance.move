#[test_only]
module insurance::test_insurance {
    // === Imports ===
    use sui::{
        test_scenario::{Self as ts, next_tx},
        coin::{Self, CoinMetadata},
        sui::SUI,
        test_utils::{assert_eq},
        clock::{Self, Clock}
    };
    use std::string::{Self, String};

    use insurance::insurance::{Self, Policy, PolicyCap, Holder};
    use insurance::helpers::init_test_helper;
    use insurance::usdc::{USDC};

    // === Constants ===
    const ADMIN: address = @0xA;
    const TEST_ADDRESS1: address = @0xB;
    const TEST_ADDRESS2: address = @0xC;

    // === Test functions ===

    #[test]
    public fun test_insurance() {

        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;
        
        // TEST_ADDRESS1 creating policy and policyCap
        next_tx(scenario, TEST_ADDRESS1);
        { 
            let time = clock::create_for_testing(ts::ctx(scenario));
            let usdc_coinmetadata = ts::take_immutable<CoinMetadata<USDC>>(scenario);
            let premiums_per_second: u64 = 100_000_000;
            let start_timestamp: u64 = 100_000_000;

            let (policy, cap) = insurance::new_policy<USDC, SUI>(
                &usdc_coinmetadata,
                &time,
                premiums_per_second,
                start_timestamp,
                ts::ctx(scenario)
            );
            transfer::public_share_object(policy);
            transfer::public_transfer(cap,TEST_ADDRESS1);

            ts::return_immutable(usdc_coinmetadata);
            clock::share_for_testing(time);
        };
        // TEST_ADDRESS2 creating holder
        next_tx(scenario, TEST_ADDRESS2);
        { 
            let policy = ts::take_shared<Policy<USDC, SUI>>(scenario);
            let holder = insurance::new_holder(&policy, ts::ctx(scenario));
            transfer::public_transfer(holder, TEST_ADDRESS2);
            ts::return_shared(policy);
        };






        
        ts::end(scenario_test);
    }
}   
