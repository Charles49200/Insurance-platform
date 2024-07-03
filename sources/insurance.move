module insurance::insurance {
    use sui::balance::{Balance, Self};
    use sui::clock::{Clock, Self};
    use sui::coin::{Coin, CoinMetadata, Self};
    use sui::math;

    // Error codes for different scenarios
    const EInsufficientCoverage: u64 = 1;
    const EInvalidStartTime: u64 = 2;
    const EInvalidAccount: u64 = 3;

    // Represents the insurance contract
    public struct INSURANCE has drop {}

    // Represents the capability of an administrator
    public struct AdminCap has key {
        id: UID
    }

    // Represents an insurance policy with two types of coins
    public struct Policy<phantom CoverCoin, phantom PremiumCoin> has key, store {
        id: UID,
        premiums_per_second: u64,
        start_timestamp: u64,
        last_update_timestamp: u64,
        accrued_coverage_per_share: u256,
        balance_cover_coin: Balance<CoverCoin>,
        balance_premium_coin: Balance<PremiumCoin>,
        cover_coin_decimal_factor: u64,
        owned_by: ID,
    }

    // Represents a capability tied to a specific policy
    public struct PolicyCap has key, store {
        id: UID,
        policy: ID,
    }

    // Represents a holder of an insurance policy
    public struct Holder<phantom CoverCoin, phantom PremiumCoin> has key, store {
        id: UID,
        policy_id: ID,
        coverage_amount: u64,
        claim_debt: u256,
    }

    // Initialization function for the insurance module
    // Sets up the AdminCap and transfers it to the contract creator
    fun init(_wtn: INSURANCE, ctx: &mut TxContext) {
        transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
    }

    // Function to create a new policy
    public fun new_policy<CoverCoin, PremiumCoin>(
        cover_coin_metadata: &CoinMetadata<CoverCoin>,
        c: &Clock,
        premiums_per_second: u64,
        start_timestamp: u64,
        ctx: &mut TxContext,
    ): (Policy<CoverCoin, PremiumCoin>, PolicyCap) {
        // Ensure the start timestamp is valid
        assert!(start_timestamp > clock_timestamp_s(c), EInvalidStartTime);

        // Create unique IDs for the policy and its capability
        let policy_id = object::new(ctx);
        let cap_id = object::new(ctx);
        let cap_inner = object::uid_to_inner(&cap_id);

        // Initialize the policy struct
        let policy = Policy {
            id: policy_id,
            premiums_per_second,
            start_timestamp,
            last_update_timestamp: start_timestamp,
            accrued_coverage_per_share: 0,
            balance_cover_coin: balance::zero(),
            balance_premium_coin: balance::zero(),
            cover_coin_decimal_factor: math::pow(10, coin::get_decimals(cover_coin_metadata)),
            owned_by: cap_inner,
        };

        // Initialize the policy capability struct
        let cap = PolicyCap {
            id: cap_id,
            policy: object::uid_to_inner(&policy.id), 
        };

        (policy, cap)
    }

    // Function to create a new holder for a policy
    public fun new_holder<CoverCoin, PremiumCoin>(
        policy: &Policy<CoverCoin, PremiumCoin>,
        ctx: &mut TxContext,
    ): Holder<CoverCoin, PremiumCoin> {
        Holder {
            id: object::new(ctx),
            policy_id: object::id(policy),
            coverage_amount: 0,
            claim_debt: 0,
        }
    }

    // Function to calculate pending coverage for a holder
    public fun pending_coverage<CoverCoin, PremiumCoin>(
        policy: &Policy<CoverCoin, PremiumCoin>,
        holder: &Holder<CoverCoin, PremiumCoin>,
        c: &Clock,
    ): u64 {
        // Ensure the holder belongs to the correct policy
        assert!(object::id(policy) == holder.policy_id, EInvalidAccount);

        let total_covered_value = balance::value(&policy.balance_cover_coin);
        let now = clock_timestamp_s(c);

        // Calculate accrued coverage per share if needed
        let accrued_coverage_per_share = if (total_covered_value == 0 || policy.last_update_timestamp >= now) {
            policy.accrued_coverage_per_share
        } else {
            calculate_accrued_coverage_per_share(
                policy.premiums_per_second,
                policy.accrued_coverage_per_share,
                total_covered_value,
                balance::value(&policy.balance_premium_coin),
                policy.cover_coin_decimal_factor,
                now - policy.last_update_timestamp,
            )
        };

        calculate_pending_coverage(holder, policy.cover_coin_decimal_factor, accrued_coverage_per_share)
    }

    // Function to purchase coverage
    public fun purchase_coverage<CoverCoin, PremiumCoin>(
        policy: &mut Policy<CoverCoin, PremiumCoin>,
        holder: &mut Holder<CoverCoin, PremiumCoin>,
        cover_coin: Coin<CoverCoin>,
        c: &Clock,
        ctx: &mut TxContext,
    ): Coin<PremiumCoin> {
        // Ensure the holder belongs to the correct policy
        assert!(object::id(policy) == holder.policy_id, EInvalidAccount);

        // Update policy state
        update(policy, clock_timestamp_s(c));

        let cover_amount = coin::value(&cover_coin);
        let mut premium_coin = coin::zero<PremiumCoin>(ctx);

        // Handle pending premium payout if holder already has coverage
        if (holder.coverage_amount != 0) {
            let pending_premium = calculate_pending_coverage(
                holder,
                policy.cover_coin_decimal_factor,
                policy.accrued_coverage_per_share,
            );
            let pending_premium = min_u64(pending_premium, balance::value(&policy.balance_premium_coin));
            if (pending_premium != 0) {
                premium_coin.balance_mut().join(policy.balance_premium_coin.split(pending_premium));
            };
        };

        // Add new coverage amount
        if (cover_amount != 0) {
            policy.balance_cover_coin.join(cover_coin.into_balance());
            holder.coverage_amount = cover_amount;
        } else {
            cover_coin.destroy_zero();
        };

        // Update holder's claim debt
        holder.claim_debt = calculate_claim_debt(
            holder.coverage_amount,
            policy.cover_coin_decimal_factor,
            policy.accrued_coverage_per_share,
        );

        premium_coin
    }

    // Function to withdraw coverage
    public fun withdraw_coverage<CoverCoin, PremiumCoin>(
        policy: &mut Policy<CoverCoin, PremiumCoin>,
        holder: &mut Holder<CoverCoin, PremiumCoin>,
        amount: u64,
        c: &Clock,
        ctx: &mut TxContext,
    ): (Coin<CoverCoin>, Coin<PremiumCoin>) {
        // Ensure the holder belongs to the correct policy
        assert!(object::id(policy) == holder.policy_id, EInvalidAccount);

        // Update policy state
        update(policy, clock_timestamp_s(c));
        assert!(holder.coverage_amount >= amount, EInsufficientCoverage);

        // Calculate pending premium payout
        let pending_premium = calculate_pending_coverage(
            holder,
            policy.cover_coin_decimal_factor,
            policy.accrued_coverage_per_share,
        );

        let mut cover_coin = coin::zero<CoverCoin>(ctx);
        let mut premium_coin = coin::zero<PremiumCoin>(ctx);

        // Withdraw specified coverage amount
        if (amount != 0) {
            holder.coverage_amount = amount;
            cover_coin.balance_mut().join(policy.balance_cover_coin.split(amount));
        };

        // Handle pending premium payout
        if (pending_premium != 0) {
            let pending_premium = min_u64(pending_premium, balance::value(&policy.balance_premium_coin));
            premium_coin.balance_mut().join(policy.balance_premium_coin.split(pending_premium));
        };

        // Update holder's claim debt
        holder.claim_debt = calculate_claim_debt(
            holder.coverage_amount,
            policy.cover_coin_decimal_factor,
            policy.accrued_coverage_per_share,
        );

        (cover_coin, premium_coin)
    }

    // Function to add premiums to a policy
    public fun add_premiums<CoverCoin, PremiumCoin>(
        policy: &mut Policy<CoverCoin, PremiumCoin>,
        c: &Clock,
        premium: Coin<PremiumCoin>,
    ) {
        // Update policy state
        update(policy, clock_timestamp_s(c));
        // Add the premium amount to the policy's premium balance
        policy.balance_premium_coin.join(premium.into_balance());
    }

    // Private functions

    // Function to get current timestamp in seconds
    fun clock_timestamp_s(c: &Clock): u64 {
        clock::timestamp_ms(c) / 1000
    }

    // Function to calculate pending coverage for a holder
    fun calculate_pending_coverage<CoverCoin, PremiumCoin>(
        holder: &Holder<CoverCoin, PremiumCoin>,
        cover_factor: u64,
        accrued_coverage_per_share: u256,
    ): u64 {
        // Calculate the pending coverage based on the holder's coverage amount, accrued coverage per share, and cover factor
        ((((holder.coverage_amount as u256) * accrued_coverage_per_share) / (cover_factor as u256)) - holder.claim_debt) as u64
    }

    // Function to update the policy state
    fun update<CoverCoin, PremiumCoin>(policy: &mut Policy<CoverCoin, PremiumCoin>, now: u64) {
        // Skip update if the policy's last update timestamp is in the future or the policy hasn't started yet
        if (policy.last_update_timestamp >= now || policy.start_timestamp > now) {
            return()
        };

        let total_covered_value = balance::value(&policy.balance_cover_coin);
        let prev_update_timestamp = policy.last_update_timestamp;
        policy.last_update_timestamp = now;

        // Skip update if there is no covered value
        if (total_covered_value == 0) {
            return()
        };

        let total_premium_value = balance::value(&policy.balance_premium_coin);

        // Calculate the new accrued coverage per share
        policy.accrued_coverage_per_share = calculate_accrued_coverage_per_share(
            policy.premiums_per_second,
            policy.accrued_coverage_per_share,
            total_covered_value,
            total_premium_value,
            policy.cover_coin_decimal_factor,
            now - prev_update_timestamp,
        );
    }

    // Function to calculate accrued coverage per share
    fun calculate_accrued_coverage_per_share(
        premiums_per_second: u64,
        last_accrued_coverage_per_share: u256,
        total_covered_token: u64,
        total_premium_value: u64,
        cover_factor: u64,
        timestamp_delta: u64,
    ): u256 {
        let total_covered_token = total_covered_token as u256;
        let total_premium_value = total_premium_value as u256;
        let premiums_per_second = premiums_per_second as u256;
        let cover_factor = cover_factor as u256;
        let timestamp_delta = timestamp_delta as u256;

        // Calculate the premium based on the elapsed time and premiums per second
        let premium = min(total_premium_value, premiums_per_second * timestamp_delta);
        // Update the accrued coverage per share based on the premium and total covered tokens
        last_accrued_coverage_per_share + ((premium * cover_factor) / total_covered_token)
    }

    // Function to calculate claim debt for a holder
    public fun calculate_claim_debt(coverage_amount: u64, cover_factor: u64, accrued_coverage_per_share: u256): u256 {
        let coverage_amount = coverage_amount as u256;
        let cover_factor = cover_factor as u256;
        // Calculate the claim debt based on the coverage amount, cover factor, and accrued coverage per share
        (coverage_amount * accrued_coverage_per_share) / cover_factor
    }

    // Function to find the minimum of two u256 values
    fun min(x: u256, y: u256): u256 {
        if (x < y) {
            x
        } else {
            y
        }
    }

    // Function to find the minimum of two u64 values
    public fun min_u64(x: u64, y: u64): u64 {
        if (x < y) {
            x
        } else {
            y
        }
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(INSURANCE {}, ctx);
    }
}
