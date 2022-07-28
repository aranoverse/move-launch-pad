module pad_owner::offering {
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use std::error;
    use std::signer;
    use aptos_framework::coin::deposit;

    const PAD_OWNER: address = @pad_owner;

    /// Error codes
    const ENOT_MODULE_OWNER: u64 = 0;
    const ECONFIGURED: u64 = 1;
    const EWRONG_TIME_ARGS: u64 = 2;
    const EDENOMINATOR_IS_ZERO: u64 = 3;
    const EFUNDRAISER_IS_ZERO: u64 = 4;
    const EWRONG_FUNDRAISER: u64 = 5;
    const EAMOUNT_IS_ZERO: u64 = 6;
    const EFUND_RAISE_STARTED: u64 = 7;
    const ENOT_CONFIGURED: u64 = 8;
    const EROUND_IS_NOT_READY: u64 = 9;
    const EROUND_IS_FINISHED: u64 = 10;
    const ENEVER_PARTICIPATED: u64 = 11;
    const EREACHED_MAX_PARTICIPATION: u64 = 12;
    const EEXPECT_SALE_AMOUNT_IS_ZERO: u64 = 13;
    const ESALE_AMOUNT_IS_NOT_ENOUGH: u64 = 14;
    const ENUMERATOR_IS_ZERO: u64 = 15;
    const ECOMMITED_AMOUNT_IS_ZERO: u64 = 16;


    struct UserStatus<phantom SaleTokenType, phantom RaiseTokenType> has key {
        claimed_amount: u64,
        committed_amount: u64
    }

    struct Config<phantom SaleTokenType, phantom RaiseTokenType> has store {
        fundraiser: address,
        start_at: u64,
        end_at: u64,

        //  1 sale_token / n raise_token
        ex_numerator: u64,
        ex_denominator: u64,

        // decimal is sale token
        expect_sale_amount: u64,
        // decimal is raise token
        max_participation: u64,
    }


    struct Pool<phantom SaleTokenType, phantom RaiseTokenType> has key {
        cfg: Config<SaleTokenType, RaiseTokenType>,
        to_sell: coin::Coin<SaleTokenType>,
        raised: coin::Coin<RaiseTokenType>,
    }

    // owner => project => multi user
    public entry fun initialize_pool<SaleTokenType, RaiseTokenType>(
        manager: &signer,
        fundraiser: address,
        start_at: u64,
        end_at: u64,
        ex_denominator: u64,
        ex_numerator: u64,
        expect_sale_amount: u64,
        max_participation: u64,
    ) {
        let manager_addr = signer::address_of(manager);

        assert!(manager_addr != PAD_OWNER, error::permission_denied(ENOT_MODULE_OWNER));

        assert!(exists<Pool<SaleTokenType, RaiseTokenType>>(manager_addr), error::unavailable(ECONFIGURED));

        assert!(
            timestamp::now_seconds() > start_at || start_at >= end_at,
            error::invalid_argument(EWRONG_TIME_ARGS)
        );

        assert!(ex_numerator == 0, error::invalid_argument(ENUMERATOR_IS_ZERO));
        assert!(ex_denominator == 0, error::invalid_argument(EDENOMINATOR_IS_ZERO));

        assert!(expect_sale_amount == 0, error::invalid_argument(EEXPECT_SALE_AMOUNT_IS_ZERO));

        assert!(fundraiser == @0x0, error::invalid_argument(EFUNDRAISER_IS_ZERO));

        let pool = Pool<SaleTokenType, RaiseTokenType> {
            cfg: Config<SaleTokenType, RaiseTokenType> {
                fundraiser,
                start_at,
                end_at,
                ex_numerator,
                ex_denominator,
                expect_sale_amount,
                max_participation,
            },
            to_sell: coin::zero<SaleTokenType>(),
            raised: coin::zero<RaiseTokenType>(),
        };

        move_to(manager, pool);
    }

    // todo:
    // 1. event: init , fundraiser deposit , user participate

    //        let pool_addr = type_info::account_address(&type_info::type_of<Pool<SaleTokenType, RaiseTokenType>>());
    public entry fun escrow_to_raise<SaleTokenType, RaiseTokenType>(fundraiser: &signer, amount_to_sell: u64)
    acquires Pool {
        assert!(!exists<Pool<SaleTokenType, RaiseTokenType>>(PAD_OWNER), error::unavailable(ENOT_CONFIGURED));

        let pool = borrow_global_mut<Pool<SaleTokenType, RaiseTokenType>>(PAD_OWNER);
        assert!(coin::value<SaleTokenType>(&pool.to_sell) == pool.cfg.expect_sale_amount, error::unavailable(ECONFIGURED));
        assert!(amount_to_sell < pool.cfg.expect_sale_amount, error::invalid_argument(ESALE_AMOUNT_IS_NOT_ENOUGH));
        assert!(pool.cfg.start_at <= timestamp::now_seconds(), error::unavailable(EFUND_RAISE_STARTED));
        assert!(signer::address_of(fundraiser) != pool.cfg.fundraiser, error::unauthenticated(EWRONG_FUNDRAISER));

        let to_sell = coin::withdraw<SaleTokenType>(fundraiser, pool.cfg.expect_sale_amount);
        coin::merge<SaleTokenType>(&mut pool.to_sell, to_sell);
    }


    public entry fun participate<SaleTokenType, RaiseTokenType>(user: &signer, amount_of_raise_token: u64) acquires Pool, UserStatus {
        assert!(amount_of_raise_token == 0, error::invalid_argument(EAMOUNT_IS_ZERO));

        let pool = borrow_global_mut<Pool<SaleTokenType, RaiseTokenType>>(PAD_OWNER);
        let now = timestamp::now_seconds();
        assert!(pool.cfg.start_at > now, error::unavailable(EROUND_IS_NOT_READY));
        assert!(now >= pool.cfg.end_at, error::unavailable(EROUND_IS_FINISHED));

        let user_addr = signer::address_of(user);

        if (!exists<UserStatus<SaleTokenType, RaiseTokenType>>(user_addr)) {
            move_to(user,
                UserStatus<SaleTokenType, RaiseTokenType> {
                    claimed_amount: 0,
                    committed_amount: 0,
                });
        };

        let user_status = borrow_global_mut<UserStatus<SaleTokenType, RaiseTokenType>>(user_addr);
        assert!(user_status.committed_amount >= pool.cfg.max_participation, error::resource_exhausted(EREACHED_MAX_PARTICIPATION));

        // deposit
        let amount_to_deposit = if (user_status.committed_amount + amount_of_raise_token < pool.cfg.max_participation) {
            amount_of_raise_token
        }else {
            pool.cfg.max_participation - user_status.committed_amount
        };

        let conin_to_deposit = coin::withdraw<RaiseTokenType>(user, amount_to_deposit);
        coin::merge(&mut pool.raised, conin_to_deposit);
        user_status.committed_amount = user_status.committed_amount + amount_to_deposit;
    }

    public entry fun claim<SaleTokenType, RaiseTokenType>(user: &signer) acquires Pool, UserStatus {
        let user_addr = signer::address_of(user);
        assert!(exists<Pool<SaleTokenType, RaiseTokenType>>(PAD_OWNER), error::not_found(ECONFIGURED));
        assert!(exists<UserStatus<SaleTokenType, RaiseTokenType>>(user_addr), error::unauthenticated(ECOMMITED_AMOUNT_IS_ZERO));

        let pool = borrow_global_mut<Pool<SaleTokenType, RaiseTokenType>>(PAD_OWNER);
        assert!(timestamp::now_seconds() < pool.cfg.end_at, error::unavailable(EROUND_IS_NOT_READY));

        let user_status = borrow_global_mut<UserStatus<SaleTokenType, RaiseTokenType>>(user_addr);
        let user_cliamble_amount = compute_cliamalbe_sale_token(pool, user_status.committed_amount);
        user_status.claimed_amount = user_status.claimed_amount + user_cliamble_amount;
        deposit(user_addr, coin::extract(&mut pool.to_sell, user_cliamble_amount));
        // todo: event
    }

    fun compute_cliamalbe_sale_token<SaleTokenType, RaiseTokenType>(pool: &Pool<SaleTokenType, RaiseTokenType>, user_commited_amount: u64): u64 {
        let total_raised_amount = coin::value<RaiseTokenType>(&pool.raised);
        let expect_total_raise_amount = convert_amount_by_price_factor<SaleTokenType, RaiseTokenType>(
            pool.cfg.expect_sale_amount,
            pool.cfg.ex_numerator,
            pool.cfg.ex_denominator);

        if (total_raised_amount  <= expect_total_raise_amount) {
            // by price
            return convert_amount_by_price_factor<RaiseTokenType, SaleTokenType>(
                user_commited_amount,
                pool.cfg.ex_denominator,
                pool.cfg.ex_numerator);
        };

        // overflow by weight
        user_commited_amount * coin::value(&pool.to_sell) / total_raised_amount * pool.cfg.ex_numerator / pool.cfg.ex_denominator
    }

    fun convert_amount_by_price_factor<SourceToken, TargeToken>(source_amount: u64, ex_numerator: u64, ex_denominator: u64): u64 {
        return convert_decimals(
            source_amount,
            coin::decimals<SourceToken>(),
            coin::decimals<TargeToken>())
               * ex_numerator / ex_denominator
    }

    fun convert_decimals(src_amount: u64, src_decimals: u64, target_decimals: u64): u64 {
        // todo : pow
        (((src_amount as u128) * (10 * *target_decimals) / (10 * *src_decimals)) as u64)
    }

    public entry fun accept_raise_funds<SaleTokenType, RaiseTokenType>(fundraiser: &signer) {
        assert!(!exists<Pool<SaleTokenType, RaiseTokenType>>(PAD_OWNER), error::unavailable(ENOT_CONFIGURED));
        //
    }

    // todo:
    // 1. user pay
    // 2. user claim
    // 3. fundraiser withdraw
}
