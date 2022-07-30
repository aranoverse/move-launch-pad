module std::pad {
    struct Cfg<phantom Offering> has key, store {
        start_at: u64,
        end_at: u64,
        sale_token: address,
        sale_token_decimal: u64,
        raise_token: address,
        raist_token_decimal: u64,
        expect_price: u128,
        denominator: u64,
        numerator: u64,
//        configs:iterable_table::IterableTable<address,Con>
    }


}
