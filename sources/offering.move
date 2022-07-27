module pad_owner::offering {
    use aptos_framework::coin;
    use aptos_framework::timestamp;

    use std::error;
    use std::signer;

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

    struct UserStatus has store, key {
        claimed_amount: u128,
        committed_amount: u128
    }

    struct Config<phantom SaleTokenType, phantom RaiseTokenType> has store {
        start_at: u64,
        end_at: u64,
        sale_token_decimal: u64,
        raise_token_decimal: u64,
        max_participation: u64,

        ex_denominator: u64,
        ex_numerator: u64,

        floor_price: u64,
        fundraiser: address,
    }


    struct Pool<phantom SaleTokenType, phantom RaiseTokenType> has key, store {
        cfg: Config<SaleTokenType, RaiseTokenType>,
        to_sell: coin::Coin<SaleTokenType>,
        raised: coin::Coin<RaiseTokenType>,
    }

    // owner => project => multi user
    public entry fun initialize_pool<SaleTokenType, RaiseTokenType>(manager: &signer,
                                                                    start_at: u64,
                                                                    end_at: u64,
                                                                    ex_denominator: u64,
                                                                    ex_numerator: u64,
                                                                    max_participation: u64,
                                                                    floor_price: u64,
                                                                    fundraiser: address) {
        let manager_addr = signer::address_of(manager);

        assert!(manager_addr == PAD_OWNER, error::permission_denied(ENOT_MODULE_OWNER));

        assert!(!exists<Pool<SaleTokenType, RaiseTokenType>>(manager_addr), error::unavailable(ECONFIGURED));

        assert!(
            timestamp::now_seconds() < start_at && start_at < end_at,
            error::invalid_argument(EWRONG_TIME_ARGS)
        );

        assert!(ex_denominator > 0, error::invalid_argument(EDENOMINATOR_IS_ZERO));

        assert!(fundraiser != @0x0, error::invalid_argument(EFUNDRAISER_IS_ZERO));

        let pool = Pool<SaleTokenType, RaiseTokenType> {
            cfg: Config<SaleTokenType, RaiseTokenType> {
                start_at,
                end_at,
                sale_token_decimal: coin::decimals<SaleTokenType>(),
                raise_token_decimal: coin::decimals<RaiseTokenType>(),
                ex_denominator,
                ex_numerator,
                max_participation,
                floor_price,
                fundraiser,
            },
            to_sell: coin::zero<SaleTokenType>(),
            raised: coin::zero<RaiseTokenType>(),
        };

        move_to(manager, pool);
    }

    //        let pool_addr = type_info::account_address(&type_info::type_of<Pool<SaleTokenType, RaiseTokenType>>());
    public entry fun escrow_raise_token<SaleTokenType, RaiseTokenType>(fundraiser: &signer, amount_to_sell: u64)acquires Pool {
        assert!(amount_to_sell>0, error::invalid_argument(EAMOUNT_IS_ZERO));
        assert!(exists<Pool<SaleTokenType, RaiseTokenType>>(PAD_OWNER), error::unavailable(ENOT_CONFIGURED));

        let pool = borrow_global_mut<Pool<SaleTokenType, RaiseTokenType>>(PAD_OWNER);
        assert!(pool.cfg.start_at > timestamp::now_seconds(), error::unavailable(EFUND_RAISE_STARTED));
        assert!(signer::address_of(fundraiser) == pool.cfg.fundraiser, error::unauthenticated(EWRONG_FUNDRAISER));

        let to_sell = coin::withdraw<SaleTokenType>(fundraiser, amount_to_sell);
        coin::merge<SaleTokenType>(&mut pool.to_sell, to_sell);
    }


    //    public entry fun pay()


    // 2.
    //
}
