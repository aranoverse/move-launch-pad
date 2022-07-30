module launch_pad::math {
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
}
