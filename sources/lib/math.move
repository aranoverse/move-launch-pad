module launch_pad::math {
    use aptos_framework::coin;

    public fun power_decimals(decimals: u64): u64 {
        if (decimals == 0) {
            return 1
        };

        let ret = 10;
        decimals = decimals - 1;
        while (decimals > 0) {
            ret = ret * 10;
            decimals = decimals - 1;
        };
        ret
    }

    public fun calculate_amount_by_price_factor<SourceToken, TargeToken>(source_amount: u64, ex_numerator: u64, ex_denominator: u64): u64 {
        // source / src_decimals * target_decimals * numberator / denominator
        let ret = (source_amount * ex_numerator as u128)
                  * (power_decimals(coin::decimals<TargeToken>()) as u128)
                  / (power_decimals(coin::decimals<SourceToken>()) as u128)
                  / (ex_denominator as u128);
        (ret as u64)
    }
}
