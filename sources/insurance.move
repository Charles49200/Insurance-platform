module insurance::insurance {
    use sui::balance::{Balance, Self};
    use sui::clock::{Clock, Self};
    use sui::coin::{Coin, CoinMetadata, Self};
    use sui::event::{Self, emit};
    use sui::math;

    const EInsufficientCoverage: u64 = 1;
    const EInvalidStartTime: u64 = 2;
    const EInvalidAccount: u64 = 3;
    const EInvalidTimestamp: u64 = 4;

    public struct INSURANCE has drop {}

    public struct AdminCap has key {
        id: UID
    }

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

    public struct PolicyCap has key, store {
        id: UID,
        policy: ID,
    }

    public struct Holder<phantom CoverCoin, phantom PremiumCoin> has key, store {
        id: UID,
        policy_id: ID,
        coverage_amount: u64,
        claim_debt: u256,
    }

    public struct PolicyCreated has copy, drop {
        policy_id: ID,
        cap_id: ID,
    }

    public struct CoveragePurchased has copy, drop {
        holder_id: ID,
        policy_id: ID,
        cover_amount: u64,
        premium_amount: u64,
    }

    public struct CoverageWithdrawn has copy, drop {
        holder_id: ID,
        policy_id: ID,
        cover_amount: u64,
        premium_amount: u64,
    }

    fun init(_wtn: INSURANCE, ctx: &mut TxContext) {
        transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
    }

    public fun new_policy<CoverCoin, PremiumCoin>(
        cover_coin_metadata: &CoinMetadata<CoverCoin>,
        c: &Clock,
        premiums_per_second: u64,
        start_timestamp: u64,
        ctx: &mut TxContext,
    ): (Policy<CoverCoin, PremiumCoin>, PolicyCap) {
        assert!(start_timestamp > clock_timestamp_s(c), EInvalidStartTime);

        let policy_id = object::new(ctx);
        let cap_id = object::new(ctx);
        let cap_inner = object::uid_to_inner(&cap_id);

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

        let cap = PolicyCap {
            id: cap_id,
            policy: object::uid_to_inner(&policy.id), 
        };

        emit(PolicyCreated {
            policy_id: object::uid_to_inner(&policy.id),
            cap_id: cap_inner,
        });

        (policy, cap)
    }

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

    public fun pending_coverage<CoverCoin, PremiumCoin>(
        policy: &Policy<CoverCoin, PremiumCoin>,
        holder: &Holder<CoverCoin, PremiumCoin>,
        c: &Clock,
    ): u64 {
        assert!(object::id(policy) == holder.policy_id, EInvalidAccount);

        let total_covered_value = balance::value(&policy.balance_cover_coin);
        let now = clock_timestamp_s(c);

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

        calculate_pending_coverage(holder.coverage_amount, policy.cover_coin_decimal_factor, accrued_coverage_per_share, holder.claim_debt)
    }

    public fun purchase_coverage<CoverCoin, PremiumCoin>(
        policy: &mut Policy<CoverCoin, PremiumCoin>,
        holder: &mut Holder<CoverCoin, PremiumCoin>,
        cover_coin: Coin<CoverCoin>,
        c: &Clock,
        ctx: &mut TxContext,
    ): Coin<PremiumCoin> {
        assert!(object::id(policy) == holder.policy_id, EInvalidAccount);

        update(policy, clock_timestamp_s(c));

        let cover_amount = coin::value(&cover_coin);
        let mut premium_coin = coin::zero<PremiumCoin>(ctx);

        if (holder.coverage_amount != 0) {
            let pending_premium = calculate_pending_coverage(
                holder.coverage_amount,
                policy.cover_coin_decimal_factor,
                policy.accrued_coverage_per_share,
                holder.claim_debt,
            );
            let pending_premium = min_u64(pending_premium, balance::value(&policy.balance_premium_coin));
            if (pending_premium != 0) {
                premium_coin.balance_mut().join(policy.balance_premium_coin.split(pending_premium));
            };
        };

        if (cover_amount != 0) {
            policy.balance_cover_coin.join(cover_coin.into_balance());
            holder.coverage_amount = cover_amount;
        } else {
            cover_coin.destroy_zero();
        };

        holder.claim_debt = calculate_claim_debt(
            holder.coverage_amount,
            policy.cover_coin_decimal_factor,
            policy.accrued_coverage_per_share,
        );

        emit(CoveragePurchased {
            holder_id: object::uid_to_inner(&holder.id),
            policy_id: object::uid_to_inner(&policy.id),
            cover_amount: cover_amount,
            premium_amount: coin::value(&premium_coin),
        });

        premium_coin
    }

    public fun withdraw_coverage<CoverCoin, PremiumCoin>(
        policy: &mut Policy<CoverCoin, PremiumCoin>,
        holder: &mut Holder<CoverCoin, PremiumCoin>,
        amount: u64,
        c: &Clock,
        ctx: &mut TxContext,
    ): (Coin<CoverCoin>, Coin<PremiumCoin>) {
        assert!(object::id(policy) == holder.policy_id, EInvalidAccount);

        update(policy, clock_timestamp_s(c));
        assert!(holder.coverage_amount >= amount, EInsufficientCoverage);

        let pending_premium = calculate_pending_coverage(
            holder.coverage_amount,
            policy.cover_coin_decimal_factor,
            policy.accrued_coverage_per_share,
            holder.claim_debt,
        );

        let mut cover_coin = coin::zero<CoverCoin>(ctx);
        let mut premium_coin = coin::zero<PremiumCoin>(ctx);

        if (amount != 0) {
            holder.coverage_amount -= amount;
            cover_coin.balance_mut().join(policy.balance_cover_coin.split(amount));
        };

        if (pending_premium != 0) {
            let pending_premium = min_u64(pending_premium, balance::value(&policy.balance_premium_coin));
            premium_coin.balance_mut().join(policy.balance_premium_coin.split(pending_premium));
        };

        holder.claim_debt = calculate_claim_debt(
            holder.coverage_amount,
            policy.cover_coin_decimal_factor,
            policy.accrued_coverage_per_share,
        );

        emit(CoverageWithdrawn {
            holder_id: object::uid_to_inner(&holder.id),
            policy_id: object::uid_to_inner(&policy.id),
            cover_amount: amount,
            premium_amount: coin::value(&premium_coin),
        });

        (cover_coin, premium_coin)
    }

    public fun add_premiums<CoverCoin, PremiumCoin>(
        policy: &mut Policy<CoverCoin, PremiumCoin>,
        c: &Clock,
        premium: Coin<PremiumCoin>,
    ) {
        update(policy, clock_timestamp_s(c));
        policy.balance_premium_coin.join(premium.into_balance());
    }

    public fun cancel_policy<CoverCoin, PremiumCoin>(
        policy: &mut Policy<CoverCoin, PremiumCoin>,
        cap: &PolicyCap,
        ctx: &mut TxContext,
    ) {
        assert!(object::uid_to_inner(&policy.id) == cap.policy, EInvalidAccount);

        let cover_balance = policy.balance_cover_coin.take(balance::value(&policy.balance_cover_coin), ctx);
        let premium_balance = policy.balance_premium_coin.take(balance::value(&policy.balance_premium_coin), ctx);

        transfer::public_transfer(cover_balance, ctx.sender());
        transfer::public_transfer(premium_balance, ctx.sender());

        object::destroy(policy.id);
        object::destroy(cap.id);
    }

    public fun transfer_policy_ownership<CoverCoin, PremiumCoin>(
        policy: &mut Policy<CoverCoin, PremiumCoin>,
        new_owner: address,
        ctx: &mut TxContext,
    ) {
        let new_owner_id = object::id_from_address(new_owner, ctx);
        policy.owned_by = new_owner_id;
    }

    public fun update_policy_details<CoverCoin, PremiumCoin>(
        policy: &mut Policy<CoverCoin, PremiumCoin>,
        new_premiums_per_second: u64,
        new_start_timestamp: u64,
        ctx: &mut TxContext,
    ) {
        assert!(new_start_timestamp > clock_timestamp_s(ctx.clock), EInvalidTimestamp);

        policy.premiums_per_second = new_premiums_per_second;
        policy.start_timestamp = new_start_timestamp;
        policy.last_update_timestamp = new_start_timestamp;
    }

    fun clock_timestamp_s(c: &Clock): u64 {
        clock::timestamp_ms(c) / 1000
    }

    fun calculate_pending_coverage(
        coverage_amount: u64,
        cover_factor: u64,
        accrued_coverage_per_share: u256,
        claim_debt: u256,
    ): u64 {
        ((((coverage_amount as u256) * accrued_coverage_per_share) / (cover_factor as u256)) - claim_debt) as u64
    }

    fun update<CoverCoin, PremiumCoin>(policy: &mut Policy<CoverCoin, PremiumCoin>, now: u64) {
        if (policy.last_update_timestamp >= now || policy.start_timestamp > now) {
            return()
        };

        let total_covered_value = balance::value(&policy.balance_cover_coin);
        let prev_update_timestamp = policy.last_update_timestamp;
        policy.last_update_timestamp = now;

        if (total_covered_value == 0) {
            return()
        };

        let total_premium_value = balance::value(&policy.balance_premium_coin);

        policy.accrued_coverage_per_share = calculate_accrued_coverage_per_share(
            policy.premiums_per_second,
            policy.accrued_coverage_per_share,
            total_covered_value,
            total_premium_value,
            policy.cover_coin_decimal_factor,
            now - prev_update_timestamp,
        );
    }

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

        let premium = min(total_premium_value, premiums_per_second * timestamp_delta);
        last_accrued_coverage_per_share + ((premium * cover_factor) / total_covered_token)
    }

    public fun calculate_claim_debt(coverage_amount: u64, cover_factor: u64, accrued_coverage_per_share: u256): u256 {
        let coverage_amount = coverage_amount as u256;
        let cover_factor = cover_factor as u256;
        (coverage_amount * accrued_coverage_per_share) / cover_factor
    }

    fun min(x: u256, y: u256): u256 {
        if (x < y) {
            x
        } else {
            y
        }
    }

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
