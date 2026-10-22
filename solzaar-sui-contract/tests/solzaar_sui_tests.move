#[test_only]
module solzaar_sui::solzaar_sui_tests {

    use std::string;

    use sui::clock::{Self, Clock};
    use sui::test_scenario;

    use solzaar_sui::marketplace;

    use std::option;

    use sui::coin;
    use sui::sui::SUI;

    use escrow::escrow;

    const MERCHANT: address = @0xA;

    const BUYER: address = @0xB;

    const ATTACKER: address = @0xC;

    fun make_images(): vector<string::String> {
        vector[
            string::utf8(b"ipfs://image1")
        ]
    }

    fun create_test_registry(
        scenario: &mut test_scenario::Scenario,
    ) {
        marketplace::create_registry_for_testing(
            test_scenario::ctx(scenario),
        );
    }

    fun create_test_merchant(
        scenario: &mut test_scenario::Scenario,
        clock: &Clock,
    ) {
        let mut registry =
            test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(scenario);

        marketplace::create_merchant(
            &mut registry,
            string::utf8(b"Stuff Store"),
            string::utf8(b"https://example.com/store.json"),
            string::utf8(b"https://example.com/logo.png"),
            string::utf8(b"https://example.com/banner.png"),
            string::utf8(b"Philippines"),
            1000u16,
            string::utf8(b"seller@example.com"),
            clock,
            test_scenario::ctx(scenario),
        );

        test_scenario::return_shared(registry);
    }


    #[test]
    fun test_create_merchant() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        // Create shared MerchantRegistry for this test.
        create_test_registry(&mut scenario);

        test_scenario::next_tx(
            &mut scenario,
            MERCHANT,
        );

                {
            let clock =
                clock::create_for_testing(
                    test_scenario::ctx(&mut scenario)
                );

            let mut registry =
                test_scenario::take_shared<
                    marketplace::MerchantRegistry
                >(&scenario);

            marketplace::create_merchant(
                &mut registry,
                string::utf8(b"Stuff Store"),
                string::utf8(b"https://example.com/store.json"),
                string::utf8(b"https://example.com/logo.png"),
                string::utf8(b"https://example.com/banner.png"),
                string::utf8(b"Philippines"),
                1000u16,
                string::utf8(b"seller@example.com"),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                registry,
            );

            clock::destroy_for_testing(clock);
        };

        test_scenario::next_tx(
            &mut scenario,
            MERCHANT,
        );

        {
            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            assert!(
                marketplace::merchant_authority(&merchant)
                    == MERCHANT,
                0
            );

            assert!(
                marketplace::merchant_active(&merchant),
                1
            );

            assert!(
                marketplace::merchant_total_sold(&merchant)
                    == 0,
                2
            );

            test_scenario::return_shared(
                merchant,
            );
        };

        test_scenario::end(scenario);
    }

    fun create_test_product(
            scenario: &mut test_scenario::Scenario,
            clock: &clock::Clock,
        ) {
            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(scenario);

            marketplace::create_product(
                &merchant,
                1u64,
                string::utf8(b"Test Product"),
                string::utf8(b"ipfs://product-description"),
                make_images(),
                string::utf8(b"General"),
                1_000_000_000u64,
                10u32,
                option::none<u16>(),
                clock,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(
                merchant,
            );
        }

    fun create_second_test_product(
        scenario: &mut test_scenario::Scenario,
        clock: &clock::Clock,
    ) {
        let merchant =
            test_scenario::take_shared<
                marketplace::MerchantProfile
            >(scenario);

        marketplace::create_product(
            &merchant,
            2u64,
            string::utf8(b"Second Product"),
            string::utf8(b"ipfs://product-2-description"),
            make_images(),
            string::utf8(b"General"),
            1_000_000_000u64,
            10u32,
                option::none<u16>(),
            clock,
            test_scenario::ctx(scenario),
        );

        test_scenario::return_shared(
            merchant,
        );
    }

        fun create_test_escrow(
            scenario: &mut test_scenario::Scenario,
            clock: &clock::Clock,
        ) {
            escrow::create_escrow(
                0u8,
                option::some(BUYER),
                option::some(MERCHANT),
                1_000_000_000u64,
                1_100_000_000u64,
                100_000_000u64,
                b"{\"marketplace\":\"solbazaar\",\"product_id\":\"1\"}",
                clock,
                test_scenario::ctx(scenario),
            );
        }

        fun deposit_test_buyer(
            scenario: &mut test_scenario::Scenario,
            clock: &clock::Clock,
        ) {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(scenario);

            let buyer_coin =
                coin::mint_for_testing<SUI>(
                    1_100_000_000u64,
                    test_scenario::ctx(scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                buyer_coin,
                clock,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(
                escrow_obj
            );
        }


    #[test]
    fun test_create_product() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        // ----------------------------------------------------
        // Create registry + merchant
        // ----------------------------------------------------

        create_test_registry(&mut scenario);

        test_scenario::next_tx(
            &mut scenario,
            MERCHANT,
        );

        {
            let ctx =
                test_scenario::ctx(&mut scenario);

            let clock =
                clock::create_for_testing(ctx);

            create_test_merchant(
                &mut scenario,
                &clock,
            );

            clock::destroy_for_testing(clock);
        };

        test_scenario::next_tx(
            &mut scenario,
            MERCHANT,
        );

        // ----------------------------------------------------
        // Create product
        // ----------------------------------------------------

        {
            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let ctx =
                test_scenario::ctx(&mut scenario);

            let clock =
                clock::create_for_testing(ctx);

            let mut images = vector[];

            images.push_back(
                string::utf8(
                    b"https://example.com/product-1.png"
                )
            );

            images.push_back(
                string::utf8(
                    b"https://example.com/product-2.png"
                )
            );

            marketplace::create_product(
                &merchant,
                1,
                string::utf8(b"Test Product"),
                string::utf8(
                    b"https://example.com/product.json"
                ),
                images,
                string::utf8(b"General"),
                1_000_000_000,
                10,
                option::none<u16>(),
                &clock,
                ctx,
            );

            clock::destroy_for_testing(clock);

            test_scenario::return_shared(
                merchant,
            );
        };

        test_scenario::next_tx(
            &mut scenario,
            MERCHANT,
        );

        // ----------------------------------------------------
        // Verify product
        // ----------------------------------------------------

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            assert!(
                marketplace::product_merchant(&product)
                    == MERCHANT,
                10
            );

            assert!(
                marketplace::product_id(&product) == 1,
                11
            );

            assert!(
                marketplace::product_price(&product)
                    == 1_000_000_000,
                12
            );

            assert!(
                marketplace::product_stock(&product) == 10,
                13
            );

            assert!(
                marketplace::product_sold(&product) == 0,
                14
            );

            assert!(
                marketplace::product_active(&product),
                15
            );

            assert!(
                !marketplace::product_deleted(&product),
                16
            );

            test_scenario::return_shared(
                product,
            );
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_completed_order_lifecycle() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        // ========================================================
        // TX 1: Create registry
        // ========================================================

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        // ========================================================
        // TX 2: Seller creates merchant
        // ========================================================

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // TX 2: Seller creates product
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut images = vector[];

            images.push_back(
                string::utf8(
                    b"https://example.com/product.png"
                )
            );

            marketplace::create_product(
                &merchant,
                1,
                string::utf8(b"Test Product"),
                string::utf8(
                    b"https://example.com/product.json"
                ),
                images,
                string::utf8(b"General"),
                1_000_000_000,
                10,
                option::none<u16>(),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                merchant,
            );
        };

        // ========================================================
        // Verify initial product stock
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            assert!(
                marketplace::product_stock(&product) == 10,
                100
            );

            test_scenario::return_shared(
                product,
            );
        };

        // ========================================================
        // TX 4: Buyer creates Solzaar escrow
        //
        // Product price:       1,000,000,000
        // Seller deposit 10%:    100,000,000
        // Buyer deposit:       1,100,000,000
        // ========================================================

        scenario.next_tx(BUYER);

        escrow::create_escrow(
            0u8,
            option::some(BUYER),
            option::some(MERCHANT),
            1_000_000_000u64,
            1_100_000_000u64,
            100_000_000u64,
            b"{\"marketplace\":\"solbazaar\",\"product_id\":\"1\"}",
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // ========================================================
        // TX 5: Buyer deposits full required amount
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let buyer_coin =
                coin::mint_for_testing<SUI>(
                    1_100_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                buyer_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            // Seller has not deposited yet,
            // therefore escrow must remain CREATED.
            assert!(
                escrow::status(&escrow_obj) == 0u8,
                101
            );

            assert!(
                escrow::deposited_a(&escrow_obj)
                    == 1_100_000_000u64,
                102
            );

            assert!(
                escrow::deposited_b(&escrow_obj) == 0u64,
                103
            );

            assert!(
                escrow::vault_balance(&escrow_obj)
                    == 1_100_000_000u64,
                104
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // TX 6: Buyer creates order record
        // Stock must be reserved: 10 -> 9
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry =
                test_scenario::take_shared<
                    marketplace::MerchantRegistry
                >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_order_record_v2(
                &mut registry,
                &merchant,
                &mut product,
                &escrow_obj,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                marketplace::product_stock(&product) == 9,
                105
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        // ========================================================
        // TX 7: Verify OrderRecord
        // ========================================================

        scenario.next_tx(BUYER);

                {
            let order =
                test_scenario::take_shared<
                    marketplace::OrderRecord
                >(&scenario);

            assert!(
                marketplace::order_buyer(&order) == BUYER,
                106
            );

            assert!(
                marketplace::order_seller(&order) == MERCHANT,
                107
            );

            assert!(
                marketplace::order_quantity(&order) == 1,
                108
            );

            assert!(
                marketplace::order_total_price(&order)
                    == 1_000_000_000u64,
                109
            );

            assert!(
                marketplace::order_security_deposit(&order)
                    == 100_000_000u64,
                110
            );

            assert!(
                !marketplace::order_completed_sale_recorded(&order),
                111
            );

            assert!(
                !marketplace::order_stock_restored(&order),
                112
            );

            test_scenario::return_shared(
                order,
            );
        };

        // ========================================================
        // TX 8: Seller deposits security deposit
        // Escrow becomes DEPOSITS_COMPLETE
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let seller_coin =
                coin::mint_for_testing<SUI>(
                    100_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                seller_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                escrow::status(&escrow_obj) == 1u8,
                113
            );

            assert!(
                escrow::deposited_a(&escrow_obj)
                    == 1_100_000_000u64,
                114
            );

            assert!(
                escrow::deposited_b(&escrow_obj)
                    == 100_000_000u64,
                115
            );

            assert!(
                escrow::vault_balance(&escrow_obj)
                    == 1_200_000_000u64,
                116
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // TX 9: Buyer proposes finalization
        //
        // Buyer gets security deposit back: 0.1 SUI
        // Seller receives sale price:       1.0 SUI
        // Donation:                         0
        //
        // Total = 1.2 SUI
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            escrow::suggest_finalization(
                &mut escrow_obj,
                100_000_000u64,
                1_100_000_000u64,
                0u64,
                b"Order completed",
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                escrow::status(&escrow_obj) == 2u8,
                117
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // TX 10: Seller accepts finalization
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            escrow::accept_finalization(
                &mut escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                escrow::status(&escrow_obj) == 3u8,
                118
            );

            assert!(
                escrow::vault_balance(&escrow_obj) == 0u64,
                119
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // TX 11: Record completed marketplace sale
        // ========================================================

        scenario.next_tx(BUYER);

                {
            let mut merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut order =
                test_scenario::take_shared<
                    marketplace::OrderRecord
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::record_completed_sale(
                &mut merchant,
                &mut product,
                &mut order,
                &escrow_obj,
            );

            // Reserved stock remains 9.
            assert!(
                marketplace::product_stock(&product) == 9,
                120
            );

            // One unit is now officially sold.
            assert!(
                marketplace::product_sold(&product) == 1,
                121
            );

            assert!(
                marketplace::merchant_total_sold(&merchant) == 1,
                122
            );

            assert!(
                marketplace::order_completed_sale_recorded(&order),
                123
            );

            assert!(
                !marketplace::order_stock_restored(&order),
                124
            );

            test_scenario::return_shared(
                merchant,
            );

            test_scenario::return_shared(
                product,
            );

            test_scenario::return_shared(
                order,
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_cancelled_order_lifecycle() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        // ========================================================
        // TX 1: Create merchant
        // ========================================================

        create_test_merchant(
            &mut scenario,
            &clock,
        );


        // ========================================================
        // TX 2: Create product
        // ========================================================

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // TX 3: Buyer creates escrow
        // ========================================================

        scenario.next_tx(BUYER);

        create_test_escrow(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // TX 4: Buyer deposits
        // ========================================================

        scenario.next_tx(BUYER);

        deposit_test_buyer(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // TX 5: Create order / reserve stock
        // 10 -> 9
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry =
                test_scenario::take_shared<
                    marketplace::MerchantRegistry
                >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_order_record_v2(
                &mut registry,
                &merchant,
                &mut product,
                &escrow_obj,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                marketplace::product_stock(&product) == 9u32,
                201
            );

            test_scenario::return_shared(
                merchant,
            );

            test_scenario::return_shared(
                product,
            );

            test_scenario::return_shared(
                escrow_obj
            );

            test_scenario::return_shared(registry);
        };

        // ========================================================
        // TX 6: Buyer cancels before seller deposits
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            escrow::withdraw_before_complete(
                &mut escrow_obj,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                escrow::status(&escrow_obj) == 4u8,
                202
            );

            assert!(
                escrow::vault_balance(&escrow_obj) == 0u64,
                203
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // TX 7: Restore reserved stock
        // 9 -> 10
        // ========================================================

        scenario.next_tx(BUYER);

                {
            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut order =
                test_scenario::take_shared<
                    marketplace::OrderRecord
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::restore_cancelled_order_stock(
                &mut product,
                &mut order,
                &escrow_obj,
            );

            assert!(
                marketplace::product_stock(&product) == 10u32,
                204
            );

            assert!(
                marketplace::order_stock_restored(&order),
                205
            );

            assert!(
                !marketplace::order_completed_sale_recorded(&order),
                206
            );

            test_scenario::return_shared(
                product,
            );

            test_scenario::return_shared(
                order,
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        clock::destroy_for_testing(clock);

        test_scenario::end(scenario);
    }

        #[test]
    fun test_submit_review_success() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        // ========================================================
        // TX 1: Create registry
        // ========================================================

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        // ========================================================
        // TX 2: Create merchant
        // ========================================================

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        
        // ========================================================
        // TX 4: Create product
        // ========================================================

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // TX 5: Buyer creates escrow
        // ========================================================

        scenario.next_tx(BUYER);

        create_test_escrow(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // TX 6: Buyer deposits required amount
        // ========================================================

        scenario.next_tx(BUYER);

        deposit_test_buyer(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // TX 7: Buyer creates order
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry =
                test_scenario::take_shared<
                    marketplace::MerchantRegistry
                >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_order_record_v2(
                &mut registry,
                &merchant,
                &mut product,
                &escrow_obj,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                marketplace::product_stock(&product) == 9u32,
                300
            );

            test_scenario::return_shared(
                merchant,
            );

            test_scenario::return_shared(
                product,
            );

            test_scenario::return_shared(
                escrow_obj
            );

            test_scenario::return_shared(registry);
        };

        // ========================================================
        // TX 8: Seller deposits security deposit
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let seller_coin =
                coin::mint_for_testing<SUI>(
                    100_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                seller_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                escrow::status(&escrow_obj) == 1u8,
                301
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // TX 9: Buyer proposes successful finalization
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            escrow::suggest_finalization(
                &mut escrow_obj,
                100_000_000u64,
                1_100_000_000u64,
                0u64,
                b"Order completed",
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                escrow::status(&escrow_obj) == 2u8,
                302
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // TX 10: Seller accepts finalization
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            escrow::accept_finalization(
                &mut escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                escrow::status(&escrow_obj) == 3u8,
                303
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // TX 11: Record completed marketplace sale
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut order =
                test_scenario::take_shared<
                    marketplace::OrderRecord
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::record_completed_sale(
                &mut merchant,
                &mut product,
                &mut order,
                &escrow_obj,
            );

            assert!(
                marketplace::order_completed_sale_recorded(&order),
                304
            );

            assert!(
                !marketplace::order_reviewed(&order),
                305
            );

            test_scenario::return_shared(
                merchant,
            );

            test_scenario::return_shared(
                product,
            );

            test_scenario::return_shared(
                order,
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // TX 12: Buyer submits 5-star review
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut order =
                test_scenario::take_shared<
                    marketplace::OrderRecord
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let mut reputation =
                test_scenario::take_shared<
                    marketplace::MerchantReputation
                >(&scenario);

            marketplace::submit_review(
                &merchant,
                &product,
                &mut order,
                &escrow_obj,
                &mut reputation,
                5u8,
                string::utf8(
                    b"Excellent product and seller"
                ),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            // Order must now be marked reviewed.
            assert!(
                marketplace::order_reviewed(&order),
                306
            );

            // Merchant reputation must match seller.
            assert!(
                marketplace::reputation_merchant(&reputation)
                    == MERCHANT,
                307
            );

            // Exactly one review.
            assert!(
                marketplace::reputation_total_reviews(&reputation)
                    == 1u64,
                308
            );

            // Rating total = 5.
            assert!(
                marketplace::reputation_total_rating(&reputation)
                    == 5u64,
                309
            );

            // Five-star bucket incremented.
            assert!(
                marketplace::reputation_five_star(&reputation)
                    == 1u64,
                310
            );

            assert!(
                marketplace::reputation_four_star(&reputation)
                    == 0u64,
                311
            );

            assert!(
                marketplace::reputation_three_star(&reputation)
                    == 0u64,
                312
            );

            assert!(
                marketplace::reputation_two_star(&reputation)
                    == 0u64,
                313
            );

            assert!(
                marketplace::reputation_one_star(&reputation)
                    == 0u64,
                314
            );

            test_scenario::return_shared(
                merchant,
            );

            test_scenario::return_shared(
                product,
            );

            test_scenario::return_shared(
                order,
            );

            test_scenario::return_shared(
                escrow_obj
            );

            test_scenario::return_shared(
                reputation,
            );
        };

        // ========================================================
        // TX 13: Verify ProductReview was created
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let review =
                test_scenario::take_shared<
                    marketplace::ProductReview
                >(&scenario);

            test_scenario::return_shared(
                review,
            );
        };

                // ========================================================
        // TX 14: Verify duplicate review is blocked
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let order =
                test_scenario::take_shared<
                    marketplace::OrderRecord
                >(&scenario);

            // The successful review above must permanently mark
            // this order as already reviewed.
            assert!(
                marketplace::order_reviewed(&order),
                315
            );

            test_scenario::return_shared(
                order,
            );
        };

        // Reputation must still contain exactly one review.
        scenario.next_tx(BUYER);

        {
            let reputation =
                test_scenario::take_shared<
                    marketplace::MerchantReputation
                >(&scenario);

            assert!(
                marketplace::reputation_total_reviews(&reputation)
                    == 1u64,
                316
            );

            assert!(
                marketplace::reputation_total_rating(&reputation)
                    == 5u64,
                317
            );

            assert!(
                marketplace::reputation_five_star(&reputation)
                    == 1u64,
                318
            );

            test_scenario::return_shared(
                reputation,
            );
        };

        clock::destroy_for_testing(clock);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 17, location = solzaar_sui::marketplace)]
    fun test_buyer_deposit_addition_overflow_rejected() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        // Create registry.
        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        // Create merchant with 10% seller deposit.
        create_test_merchant(
            &mut scenario,
            &clock,
        );

        // Create an extremely expensive product.
        scenario.next_tx(MERCHANT);

        {
            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            marketplace::create_product(
                &merchant,
                999u64,
                string::utf8(b"Overflow Product"),
                string::utf8(b"ipfs://overflow-product"),
                make_images(),
                string::utf8(b"General"),
                17_000_000_000_000_000_000u64,
                1u32,
                option::none<u16>(),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                merchant,
            );
        };

        // Create matching escrow.
        //
        // total_price      = 17,000,000,000,000,000,000
        // security deposit =  1,700,000,000,000,000,000
        //
        // Their addition exceeds u64::MAX.
        scenario.next_tx(BUYER);

        escrow::create_escrow(
            0u8,
            option::some(BUYER),
            option::some(MERCHANT),
            17_000_000_000_000_000_000u64,
            17_000_000_000_000_000_000u64,
            1_700_000_000_000_000_000u64,
            b"{\"marketplace\":\"solbazaar\",\"product_id\":\"999\"}",
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // create_order_record must abort with E_MATH_OVERFLOW (17)
        // while calculating expected_buyer_deposit.
        scenario.next_tx(BUYER);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_order_record_v2(
                &mut registry,
                &merchant,
                &mut product,
                &escrow_obj,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            // Expected abort before reaching here.
            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    fun test_product_messaging_success() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        // Create registry.
        create_test_registry(&mut scenario);

        // Seller creates merchant.
        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        // Seller creates product.
        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // Buyer -> Seller message
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::send_product_message(
                &product,
                BUYER,
                string::utf8(b"Is this still available?"),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        // Verify ChatMessage exists.
        scenario.next_tx(BUYER);

        {
            let message =
                test_scenario::take_shared<
                    marketplace::ChatMessage
                >(&scenario);

            assert!(
                marketplace::message_buyer(&message) == BUYER,
                400
            );

            assert!(
                marketplace::message_seller(&message) == MERCHANT,
                401
            );

            assert!(
                marketplace::message_sender(&message) == BUYER,
                402
            );

            assert!(
                marketplace::message_recipient(&message) == MERCHANT,
                403
            );

            test_scenario::return_shared(message);
        };

        // ========================================================
        // Seller -> Buyer reply
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::send_product_message(
                &product,
                BUYER,
                string::utf8(b"Yes, it is available."),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        // Verify seller reply ChatMessage exists.
        scenario.next_tx(MERCHANT);

        {
            let message =
                test_scenario::take_shared<
                    marketplace::ChatMessage
                >(&scenario);

            assert!(
                marketplace::message_buyer(&message) == BUYER,
                404
            );

            assert!(
                marketplace::message_seller(&message) == MERCHANT,
                405
            );

            assert!(
                marketplace::message_sender(&message) == MERCHANT,
                406
            );

            assert!(
                marketplace::message_recipient(&message) == BUYER,
                407
            );

            test_scenario::return_shared(message);
        };

        clock::destroy_for_testing(clock);

        test_scenario::end(scenario);
    }

        #[test]
    #[expected_failure(
        abort_code = 0,
        location = solzaar_sui::marketplace
    )]
    fun test_product_message_unauthorized_sender_rejected() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ATTACKER tries to impersonate a participant.
        scenario.next_tx(ATTACKER);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::send_product_message(
                &product,
                BUYER,
                string::utf8(b"Fake message"),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            // Must never reach here.
            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);

        test_scenario::end(scenario);
    }

        #[test]
    #[expected_failure(
        abort_code = 28,
        location = solzaar_sui::marketplace
    )]
    fun test_product_message_empty_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);
        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);

        scenario.next_tx(BUYER);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::send_product_message(
                &product,
                BUYER,
                string::utf8(b""),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(
        abort_code = 29,
        location = solzaar_sui::marketplace
    )]
    fun test_product_message_too_long_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);
        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);

        scenario.next_tx(BUYER);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::send_product_message(
                &product,
                BUYER,
                string::utf8(
                    b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                ),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(
        abort_code = 11,
        location = solzaar_sui::marketplace
    )]
    fun test_product_message_buyer_equals_seller_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);
        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::send_product_message(
                &product,
                MERCHANT,
                string::utf8(b"Invalid self message"),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(
        abort_code = 6,
        location = solzaar_sui::marketplace
    )]
    fun test_product_message_deleted_product_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);
        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);

        // Seller deletes product.
        scenario.next_tx(MERCHANT);

        {
            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::delete_product(
                &mut product,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        // Buyer attempts to message deleted product.
        scenario.next_tx(BUYER);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::send_product_message(
                &product,
                BUYER,
                string::utf8(b"Is this available?"),
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    fun test_special_price_offer_success() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        // Create merchant.
        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        // Create product.
        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // Seller creates special offer for BUYER
        //
        // Public price:  1.0 SUI
        // Special price: 0.8 SUI
        // Quantity:      2
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                2u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        // ========================================================
        // Verify SpecialPriceOffer
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let offer =
                test_scenario::take_shared<
                    marketplace::SpecialPriceOffer
                >(&scenario);

            assert!(
                marketplace::special_offer_seller(&offer)
                    == MERCHANT,
                500
            );

            assert!(
                marketplace::special_offer_buyer(&offer)
                    == BUYER,
                501
            );

            assert!(
                marketplace::special_offer_unit_price(&offer)
                    == 800_000_000u64,
                502
            );

            assert!(
                marketplace::special_offer_quantity(&offer)
                    == 2u32,
                503
            );

            assert!(
                marketplace::special_offer_active(&offer),
                505
            );

            assert!(
                !marketplace::special_offer_used(&offer),
                506
            );

            test_scenario::return_shared(offer);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    #[expected_failure(
        abort_code = 0,
        location = solzaar_sui::marketplace
    )]
    fun test_special_price_offer_non_seller_rejected() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ATTACKER tries to create an offer
        // for a product owned by MERCHANT.
        scenario.next_tx(ATTACKER);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(
        abort_code = 30,
        location = solzaar_sui::marketplace
    )]
    fun test_special_price_offer_zero_price_rejected() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::create_special_price_offer(
                &product,
                BUYER,
                0u64,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(
        abort_code = 8,
        location = solzaar_sui::marketplace
    )]
    fun test_special_price_offer_zero_quantity_rejected() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                0u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    #[expected_failure(
        abort_code = 9,
        location = solzaar_sui::marketplace
    )]
    fun test_special_price_offer_insufficient_stock_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        create_test_merchant(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<marketplace::Product>(
                    &scenario
                );

            // Test product stock is 10.
            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                11u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    #[test]
    #[expected_failure(
        abort_code = 11,
        location = solzaar_sui::marketplace
    )]
    fun test_special_price_offer_buyer_equals_seller_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        create_test_merchant(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<marketplace::Product>(
                    &scenario
                );

            marketplace::create_special_price_offer(
                &product,
                MERCHANT,
                800_000_000u64,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    #[test]
    fun test_special_price_offer_past_expiry_allowed() {
        let mut scenario = test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let mut clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        create_test_merchant(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);

        // Move testing clock forward.
        clock::increment_for_testing(
            &mut clock,
            10_000u64
        );

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<marketplace::Product>(
                    &scenario
                );

            // expires_at is already behind current clock.
            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    fun test_special_price_checkout_success() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        // Create merchant.
        create_test_merchant(
            &mut scenario,
            &clock,
        );

        // Create product:
        // public price = 1 SUI
        // stock = 10
        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // Seller creates special offer
        //
        // 0.8 SUI x 2 = 1.6 SUI
        // Seller deposit 10% = 0.16 SUI
        // Buyer required = 1.76 SUI
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                2u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        // ========================================================
        // Buyer creates escrow matching negotiated price
        // ========================================================

        scenario.next_tx(BUYER);

        escrow::create_escrow(
            0u8,
            option::some(BUYER),
            option::some(MERCHANT),

            // negotiated total
            1_600_000_000u64,

            // buyer required deposit
            1_760_000_000u64,

            // seller security deposit
            160_000_000u64,

            b"{\"marketplace\":\"solbazaar\",\"special_offer\":true}",
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // ========================================================
        // Buyer deposits exact required amount
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let buyer_coin =
                coin::mint_for_testing<SUI>(
                    1_760_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                buyer_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // Buyer accepts special offer / creates order
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut offer =
                test_scenario::take_shared<
                    marketplace::SpecialPriceOffer
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_special_order_record(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            // Stock 10 -> 8.
            assert!(
                marketplace::product_stock(&product)
                    == 8u32,
                600
            );

            // Offer must be consumed.
            assert!(
                marketplace::special_offer_used(&offer),
                601
            );

            assert!(
                !marketplace::special_offer_active(&offer),
                602
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        // ========================================================
        // Verify negotiated OrderRecord
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let order =
                test_scenario::take_shared<
                    marketplace::OrderRecord
                >(&scenario);

            assert!(
                marketplace::order_buyer(&order)
                    == BUYER,
                603
            );

            assert!(
                marketplace::order_seller(&order)
                    == MERCHANT,
                604
            );

            assert!(
                marketplace::order_quantity(&order)
                    == 2u32,
                605
            );

            assert!(
                marketplace::order_unit_price(&order)
                    == 800_000_000u64,
                608
            );

            assert!(
                marketplace::order_total_price(&order)
                    == 1_600_000_000u64,
                606
            );

            assert!(
                marketplace::order_security_deposit(&order)
                    == 160_000_000u64,
                607
            );

            test_scenario::return_shared(order);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    #[expected_failure(
        abort_code = 33,
        location = solzaar_sui::marketplace
    )]
    fun test_special_price_checkout_wrong_buyer_rejected() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // Offer is specifically for BUYER.
        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                2u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        // ATTACKER creates an otherwise valid escrow.
        scenario.next_tx(ATTACKER);

        escrow::create_escrow(
            0u8,
            option::some(ATTACKER),
            option::some(MERCHANT),
            1_600_000_000u64,
            1_760_000_000u64,
            160_000_000u64,
            b"{\"marketplace\":\"solbazaar\",\"special_offer\":true}",
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // ATTACKER funds their escrow correctly.
        scenario.next_tx(ATTACKER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let attacker_coin =
                coin::mint_for_testing<SUI>(
                    1_760_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                attacker_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ATTACKER attempts to consume BUYER's offer.
        scenario.next_tx(ATTACKER);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut offer =
                test_scenario::take_shared<
                    marketplace::SpecialPriceOffer
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_special_order_record(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    #[expected_failure(
        abort_code = 12,
        location = solzaar_sui::marketplace
    )]
    fun test_special_price_checkout_wrong_amount_rejected() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // Valid special offer:
        // 0.8 SUI x 2 = 1.6 SUI
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                2u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        // ========================================================
        // Buyer creates WRONG escrow.
        //
        // Reference amount deliberately uses 1.0 SUI
        // instead of negotiated 1.6 SUI.
        //
        // Escrow itself is internally consistent:
        // total = 1.0 SUI
        // security deposit = 0.1 SUI
        // buyer deposit = 1.1 SUI
        // ========================================================

        scenario.next_tx(BUYER);

        escrow::create_escrow(
            0u8,
            option::some(BUYER),
            option::some(MERCHANT),

            // WRONG negotiated total.
            1_000_000_000u64,

            // Internally valid for this malicious escrow.
            1_100_000_000u64,

            100_000_000u64,

            b"{\"marketplace\":\"solbazaar\",\"special_offer\":true}",
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // Fund malicious escrow completely.
        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let buyer_coin =
                coin::mint_for_testing<SUI>(
                    1_100_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                buyer_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // Attempt checkout.
        //
        // Must reject because offer requires 1.6 SUI,
        // while escrow reference amount is only 1.0 SUI.
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut offer =
                test_scenario::take_shared<
                    marketplace::SpecialPriceOffer
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_special_order_record(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    #[expected_failure(
        abort_code = 32,
        location = solzaar_sui::marketplace
    )]
    fun test_special_price_checkout_replay_rejected() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // Create valid special offer
        // 0.8 SUI x 2 = 1.6 SUI
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                2u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(product);
        };

        // ========================================================
        // Create correct escrow
        // ========================================================

        scenario.next_tx(BUYER);

        escrow::create_escrow(
            0u8,
            option::some(BUYER),
            option::some(MERCHANT),
            1_600_000_000u64,
            1_760_000_000u64,
            160_000_000u64,
            b"{\"marketplace\":\"solbazaar\",\"special_offer\":true}",
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // Buyer funds escrow.
        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let buyer_coin =
                coin::mint_for_testing<SUI>(
                    1_760_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                buyer_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // First checkout succeeds and consumes offer
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut offer =
                test_scenario::take_shared<
                    marketplace::SpecialPriceOffer
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_special_order_record(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                marketplace::special_offer_used(&offer),
                700
            );

            assert!(
                !marketplace::special_offer_active(&offer),
                701
            );

            assert!(
                marketplace::product_stock(&product)
                    == 8u32,
                702
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        // ========================================================
        // Second attempt with SAME consumed offer
        //
        // Must abort before another order can be created.
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut offer =
                test_scenario::take_shared<
                    marketplace::SpecialPriceOffer
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_special_order_record(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    #[expected_failure(
        abort_code = 34,
        location = solzaar_sui::marketplace
    )]
    fun test_special_price_checkout_wrong_product_rejected() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // Create Product A
        // ========================================================

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // Get Product A's exact Sui object ID.
        scenario.next_tx(MERCHANT);

        let product_a_id;

        {
            let product_a =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            product_a_id =
                marketplace::product_object_id(
                    &product_a
                );

            test_scenario::return_shared(
                product_a
            );
        };

        // ========================================================
        // Create Product B
        // ========================================================

        scenario.next_tx(MERCHANT);

        create_second_test_product(
            &mut scenario,
            &clock,
        );

        // Because there are now two Product objects,
        // select Product A explicitly by object ID.
        //
        // Create the offer specifically for Product A.
        scenario.next_tx(MERCHANT);

        {
            let product_a =
                test_scenario::take_shared_by_id<
                    marketplace::Product
                >(
                    &scenario,
                    product_a_id,
                );

            marketplace::create_special_price_offer(
                &product_a,
                BUYER,
                800_000_000u64,
                2u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                product_a
            );
        };

        // ========================================================
        // Find Product B's object ID.
        //
        // We know Product A's object ID, but take_shared<Product>()
        // would now be ambiguous, so locate Product B through its
        // business product_id == 2.
        // ========================================================

        scenario.next_tx(MERCHANT);

        let product_b_id;

        {
            // Product A is explicitly removed temporarily,
            // leaving Product B as the only available Product.
            let product_a =
                test_scenario::take_shared_by_id<
                    marketplace::Product
                >(
                    &scenario,
                    product_a_id,
                );

            let product_b =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            assert!(
                marketplace::product_id(&product_b)
                    == 2u64,
                710
            );

            product_b_id =
                marketplace::product_object_id(
                    &product_b
                );

            test_scenario::return_shared(
                product_a
            );

            test_scenario::return_shared(
                product_b
            );
        };

        // ========================================================
        // Create an otherwise valid escrow.
        //
        // Offer:
        // 0.8 SUI x 2 = 1.6 SUI
        //
        // Seller deposit:
        // 10% = 0.16 SUI
        //
        // Buyer deposit:
        // 1.6 + 0.16 = 1.76 SUI
        // ========================================================

        scenario.next_tx(BUYER);

        escrow::create_escrow(
            0u8,
            option::some(BUYER),
            option::some(MERCHANT),
            1_600_000_000u64,
            1_760_000_000u64,
            160_000_000u64,
            b"{\"marketplace\":\"solbazaar\",\"special_offer\":true}",
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // Fund escrow completely.
        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let buyer_coin =
                coin::mint_for_testing<SUI>(
                    1_760_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                buyer_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // ATTACK:
        //
        // Offer belongs to Product A,
        // but buyer tries to checkout Product B.
        //
        // Must abort with:
        // E_SPECIAL_OFFER_PRODUCT_MISMATCH = 34
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product_b =
                test_scenario::take_shared_by_id<
                    marketplace::Product
                >(
                    &scenario,
                    product_b_id,
                );

            let mut offer =
                test_scenario::take_shared<
                    marketplace::SpecialPriceOffer
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_special_order_record(
                &mut registry,
                &merchant,
                &mut product_b,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                merchant
            );

            test_scenario::return_shared(
                product_b
            );

            test_scenario::return_shared(
                offer
            );

            test_scenario::return_shared(
                escrow_obj
            );
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    fun test_special_price_checkout_past_expiry_allowed() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let mut clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // Create a VALID offer.
        //
        // Current test clock starts at 0.
        // Offer expires at 60,000 ms.
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            marketplace::create_special_price_offer(
                &product,
                BUYER,
                800_000_000u64,
                2u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                product
            );
        };

        // ========================================================
        // Buyer creates correct negotiated escrow.
        // 0.8 SUI x 2 = 1.6 SUI
        // seller deposit = 0.16 SUI
        // buyer deposit = 1.76 SUI
        // ========================================================

        scenario.next_tx(BUYER);

        escrow::create_escrow(
            0u8,
            option::some(BUYER),
            option::some(MERCHANT),
            1_600_000_000u64,
            1_760_000_000u64,
            160_000_000u64,
            b"{\"marketplace\":\"solbazaar\",\"special_offer\":true}",
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // Fund escrow completely.
        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let buyer_coin =
                coin::mint_for_testing<SUI>(
                    1_760_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                buyer_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // Advance time beyond offer expiry.
        //
        // expiry = 60,000 ms
        // new time = 60,001 ms
        // ========================================================

        clock::increment_for_testing(
            &mut clock,
            60_001u64,
        );

        // ========================================================
        // Checkout should succeed even after the old expiry timestamp.
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut offer =
                test_scenario::take_shared<
                    marketplace::SpecialPriceOffer
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_special_order_record(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                merchant
            );

            test_scenario::return_shared(
                product
            );

            test_scenario::return_shared(
                offer
            );

            test_scenario::return_shared(
                escrow_obj
            );
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

        #[test]
    fun test_purchase_offer_success() {
        let mut scenario =
            test_scenario::begin(MERCHANT);

        // ========================================================
        // Create registry
        // ========================================================

        create_test_registry(&mut scenario);

        // ========================================================
        // Create merchant
        // ========================================================

        scenario.next_tx(MERCHANT);

        let clock =
            clock::create_for_testing(
                test_scenario::ctx(&mut scenario)
            );

        create_test_merchant(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // Create product
        // ========================================================

        scenario.next_tx(MERCHANT);

        create_test_product(
            &mut scenario,
            &clock,
        );

        // ========================================================
        // Buyer creates escrow
        //
        // Offer price:     0.8 SUI
        // Quantity:        1
        // Total:           0.8 SUI
        // Security 10%:    0.08 SUI
        // Buyer deposit:   0.88 SUI
        // ========================================================

        scenario.next_tx(BUYER);

        escrow::create_escrow(
            0u8,
            option::some(BUYER),
            option::some(MERCHANT),

            800_000_000u64,
            880_000_000u64,
            80_000_000u64,

            b"{\"marketplace\":\"solbazaar\",\"purchase_offer\":true}",

            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // ========================================================
        // Buyer funds escrow with exact 0.88 SUI
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let buyer_coin =
                coin::mint_for_testing<SUI>(
                    880_000_000u64,
                    test_scenario::ctx(&mut scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                buyer_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                escrow_obj
            );
        };

        // ========================================================
        // Buyer creates funded PurchaseOffer
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let mut registry =
                test_scenario::take_shared<
                    marketplace::MerchantRegistry
                >(&scenario);
                
            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            marketplace::create_purchase_offer_v2(
                &mut registry,
                &merchant,
                &product,
                &escrow_obj,
                800_000_000u64,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(
                merchant
            );

            test_scenario::return_shared(
                product
            );

            test_scenario::return_shared(
                escrow_obj
            );
            test_scenario::return_shared(registry);
        };

        // ========================================================
        // Verify PurchaseOffer
        // ========================================================

        scenario.next_tx(BUYER);

        {
            let offer =
                test_scenario::take_shared<
                    marketplace::PurchaseOffer
                >(&scenario);

            assert!(
                marketplace::purchase_offer_unit_price(
                    &offer
                ) == 800_000_000u64,
                800
            );

            assert!(
                marketplace::purchase_offer_total_price(
                    &offer
                ) == 800_000_000u64,
                801
            );

            assert!(
                marketplace::purchase_offer_buyer_deposit(
                    &offer
                ) == 880_000_000u64,
                802
            );

            assert!(
                marketplace::purchase_offer_active(
                    &offer
                ),
                803
            );

            test_scenario::return_shared(
                offer
            );
        };


        // ========================================================
        // Seller accepts buyer-funded purchase offer
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let mut product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let mut offer =
                test_scenario::take_shared<
                    marketplace::PurchaseOffer
                >(&scenario);

            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            let seller_coin = coin::mint_for_testing<SUI>(
                80_000_000u64,
                test_scenario::ctx(&mut scenario),
            );
            escrow::deposit(
                &mut escrow_obj,
                seller_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );
            assert!(escrow::status(&escrow_obj) == 1u8, 990);

            marketplace::accept_purchase_offer(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            // Stock reserved: 10 -> 9
            assert!(
                marketplace::product_stock(&product) == 9u32,
                810
            );

            assert!(
                !marketplace::purchase_offer_active(&offer),
                811
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        // ========================================================
        // Verify new OrderRecord
        // ========================================================

        scenario.next_tx(MERCHANT);

        {
            let order =
                test_scenario::take_shared<
                    marketplace::OrderRecord
                >(&scenario);

            assert!(
                marketplace::order_buyer(&order) == BUYER,
                812
            );

            assert!(
                marketplace::order_seller(&order) == MERCHANT,
                813
            );

            assert!(
                marketplace::order_quantity(&order) == 1u32,
                814
            );

            assert!(
                marketplace::order_total_price(&order)
                    == 800_000_000u64,
                815
            );

            assert!(
                marketplace::order_security_deposit(&order)
                    == 80_000_000u64,
                816
            );

            assert!(
                !marketplace::order_completed_sale_recorded(
                    &order
                ),
                817
            );

            test_scenario::return_shared(order);
        };


        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    // ========================================================
    // Setup a fully funded buyer PurchaseOffer
    // For acceptance security tests
    // ========================================================

    fun setup_funded_purchase_offer(
        scenario: &mut test_scenario::Scenario,
        clock: &Clock,
    ) {
        create_test_registry(scenario);

        scenario.next_tx(MERCHANT);
        create_test_merchant(scenario, clock);

        scenario.next_tx(MERCHANT);
        create_test_product(scenario, clock);

        // Buyer creates escrow
        scenario.next_tx(BUYER);

        escrow::create_escrow(
            0u8,
            option::some(BUYER),
            option::some(MERCHANT),
            800_000_000u64,
            880_000_000u64,
            80_000_000u64,
            b"{\"marketplace\":\"solbazaar\",\"purchase_offer\":true}",
            clock,
            test_scenario::ctx(scenario),
        );

        // Buyer funds escrow
        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(scenario);

            let buyer_coin =
                coin::mint_for_testing<SUI>(
                    880_000_000u64,
                    test_scenario::ctx(scenario),
                );

            escrow::deposit(
                &mut escrow_obj,
                buyer_coin,
                clock,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(escrow_obj);
        };

        // Buyer creates PurchaseOffer
        scenario.next_tx(BUYER);

        {
            let mut registry =
                test_scenario::take_shared<
                    marketplace::MerchantRegistry
                >(scenario);
            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(scenario);

            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(scenario);

            marketplace::create_purchase_offer_v2(
                &mut registry,
                &merchant,
                &product,
                &escrow_obj,
                800_000_000u64,
                1u32,
                clock,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };
    }


    // ========================================================
    // SECURITY 1: Unauthorized seller
    // ========================================================

    #[test]
    #[expected_failure(
        abort_code = 0,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_unauthorized_accept_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);

        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);

        scenario.next_tx(ATTACKER);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant = test_scenario::take_shared<
                marketplace::MerchantProfile
            >(&scenario);

            let mut product = test_scenario::take_shared<
                marketplace::Product
            >(&scenario);

            let mut offer = test_scenario::take_shared<
                marketplace::PurchaseOffer
            >(&scenario);

            let escrow_obj = test_scenario::take_shared<
                escrow::Escrow
            >(&scenario);

            marketplace::accept_purchase_offer(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ========================================================
    // SECURITY 2: Expired purchase offer
    // ========================================================

    #[test]
    fun test_purchase_offer_past_expiry_accept_allowed() {
        let mut scenario = test_scenario::begin(MERCHANT);

        let mut clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);

        clock::increment_for_testing(
            &mut clock,
            60_001u64,
        );

        scenario.next_tx(MERCHANT);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant = test_scenario::take_shared<
                marketplace::MerchantProfile
            >(&scenario);

            let mut product = test_scenario::take_shared<
                marketplace::Product
            >(&scenario);

            let mut offer = test_scenario::take_shared<
                marketplace::PurchaseOffer
            >(&scenario);

            let mut escrow_obj = test_scenario::take_shared<
                escrow::Escrow
            >(&scenario);

            let seller_coin = coin::mint_for_testing<SUI>(
                80_000_000u64,
                test_scenario::ctx(&mut scenario),
            );
            escrow::deposit(
                &mut escrow_obj,
                seller_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );
            assert!(escrow::status(&escrow_obj) == 1u8, 990);

            marketplace::accept_purchase_offer(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ========================================================
    // SECURITY 3: Double acceptance / replay
    // ========================================================

    #[test]
    #[expected_failure(
        abort_code = 36,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_double_accept_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);

        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);

        // First acceptance succeeds
        scenario.next_tx(MERCHANT);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant = test_scenario::take_shared<
                marketplace::MerchantProfile
            >(&scenario);

            let mut product = test_scenario::take_shared<
                marketplace::Product
            >(&scenario);

            let mut offer = test_scenario::take_shared<
                marketplace::PurchaseOffer
            >(&scenario);

            let mut escrow_obj = test_scenario::take_shared<
                escrow::Escrow
            >(&scenario);

            let seller_coin = coin::mint_for_testing<SUI>(
                80_000_000u64,
                test_scenario::ctx(&mut scenario),
            );
            escrow::deposit(
                &mut escrow_obj,
                seller_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );
            assert!(escrow::status(&escrow_obj) == 1u8, 990);

            marketplace::accept_purchase_offer(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        // Second acceptance must fail
        scenario.next_tx(MERCHANT);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant = test_scenario::take_shared<
                marketplace::MerchantProfile
            >(&scenario);

            let mut product = test_scenario::take_shared<
                marketplace::Product
            >(&scenario);

            let mut offer = test_scenario::take_shared<
                marketplace::PurchaseOffer
            >(&scenario);

            let escrow_obj = test_scenario::take_shared<
                escrow::Escrow
            >(&scenario);

            marketplace::accept_purchase_offer(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    // Security regression: one funded escrow cannot reserve stock twice.
    #[test]
    #[expected_failure(abort_code = 40, location = solzaar_sui::marketplace)]
    fun test_security_same_escrow_two_regular_orders_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);
        create_test_registry(&mut scenario);
        scenario.next_tx(MERCHANT);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        create_test_merchant(&mut scenario, &clock);
        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);
        scenario.next_tx(BUYER);
        create_test_escrow(&mut scenario, &clock);
        scenario.next_tx(BUYER);
        deposit_test_buyer(&mut scenario, &clock);
        scenario.next_tx(BUYER);
        {
            let mut registry = test_scenario::take_shared<marketplace::MerchantRegistry>(&scenario);
            let merchant = test_scenario::take_shared<marketplace::MerchantProfile>(&scenario);
            let mut product = test_scenario::take_shared<marketplace::Product>(&scenario);
            let escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);
            marketplace::create_order_record_v2(
                &mut registry, &merchant, &mut product, &escrow_obj,
                1u32, &clock, test_scenario::ctx(&mut scenario),
            );
            // Must abort with E_ESCROW_ALREADY_BOUND (40).
            marketplace::create_order_record_v2(
                &mut registry, &merchant, &mut product, &escrow_obj,
                1u32, &clock, test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(registry);
            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(escrow_obj);
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Security regression: an escrow already used for a normal order
    // must not be reused to accept a buyer-funded purchase offer.
    #[test]
    #[expected_failure(abort_code = 40, location = solzaar_sui::marketplace)]
    fun test_security_regular_order_then_purchase_offer_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);
        create_test_registry(&mut scenario);
        scenario.next_tx(MERCHANT);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        create_test_merchant(&mut scenario, &clock);
        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);

        // Original product price is 1 SUI. The escrow matches a normal order.
        scenario.next_tx(BUYER);
        create_test_escrow(&mut scenario, &clock);
        scenario.next_tx(BUYER);
        deposit_test_buyer(&mut scenario, &clock);

        // Bind the escrow to a regular order first.
        scenario.next_tx(BUYER);
        {
            let mut registry = test_scenario::take_shared<marketplace::MerchantRegistry>(&scenario);
            let merchant = test_scenario::take_shared<marketplace::MerchantProfile>(&scenario);
            let mut product = test_scenario::take_shared<marketplace::Product>(&scenario);
            let escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);
            marketplace::create_order_record_v2(
                &mut registry, &merchant, &mut product, &escrow_obj,
                1u32, &clock, test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(registry);
            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(escrow_obj);
        };

        // Change the listing to 2 SUI. The original 1 SUI escrow now
        // also satisfies the discounted-offer amount checks.
        scenario.next_tx(MERCHANT);
        {
            let mut product = test_scenario::take_shared<marketplace::Product>(&scenario);
            marketplace::update_product(
                &mut product,
                string::utf8(b"Test Product"),
                string::utf8(b"ipfs://product-description"),
                make_images(),
                string::utf8(b"General"),
                2_000_000_000u64,
                9u32,
                true,
                option::none<u16>(),
                &clock,
                test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(product);
        };

        // Buyer can construct a valid discounted offer for that escrow,
        // even though it is already bound. Acceptance must reject reuse.
        scenario.next_tx(BUYER);

        {
            let mut registry =
                test_scenario::take_shared<
                    marketplace::MerchantRegistry
                >(&scenario);

            let merchant =
                test_scenario::take_shared<
                    marketplace::MerchantProfile
                >(&scenario);

            let product =
                test_scenario::take_shared<
                    marketplace::Product
                >(&scenario);

            let escrow_obj =
                test_scenario::take_shared<
                    escrow::Escrow
                >(&scenario);

            // Must abort: escrow already bound to a regular order.
            marketplace::create_purchase_offer_v2(
                &mut registry,
                &merchant,
                &product,
                &escrow_obj,
                1_000_000_000u64,
                1u32,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(registry);
            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(escrow_obj);
        };

        // Acceptance requires the escrow to be fully funded (status 1).
        scenario.next_tx(MERCHANT);
        {
            let mut escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);
            let seller_coin = coin::mint_for_testing<SUI>(
                100_000_000u64, test_scenario::ctx(&mut scenario),
            );
            escrow::deposit(
                &mut escrow_obj, seller_coin, &clock,
                test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(escrow_obj);
        };

        scenario.next_tx(MERCHANT);
        {
            let mut registry = test_scenario::take_shared<marketplace::MerchantRegistry>(&scenario);
            let merchant = test_scenario::take_shared<marketplace::MerchantProfile>(&scenario);
            let mut product = test_scenario::take_shared<marketplace::Product>(&scenario);
            let mut offer = test_scenario::take_shared<marketplace::PurchaseOffer>(&scenario);
            let escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);
            marketplace::accept_purchase_offer(
                &mut registry, &merchant, &mut product, &mut offer,
                &escrow_obj, &clock, test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(registry);
            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Security regression:
    // Legacy V1 checkout must always abort.
    // All new orders must use create_order_record_v2.
    #[test]
    #[expected_failure(abort_code = 41, location = solzaar_sui::marketplace)]
    fun test_legacy_checkout_disabled() {
        let mut scenario = test_scenario::begin(MERCHANT);

        create_test_registry(&mut scenario);

        scenario.next_tx(MERCHANT);

        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        create_test_merchant(&mut scenario, &clock);

        scenario.next_tx(MERCHANT);
        create_test_product(&mut scenario, &clock);

        scenario.next_tx(BUYER);
        create_test_escrow(&mut scenario, &clock);

        scenario.next_tx(BUYER);

        let merchant =
            test_scenario::take_shared<marketplace::MerchantProfile>(
                &scenario
            );

        let mut product =
            test_scenario::take_shared<marketplace::Product>(
                &scenario
            );

        let escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(
                &scenario
            );

        // Original V1 signature: no registry argument.
        // Must abort with E_LEGACY_CHECKOUT_DISABLED (41).
        marketplace::create_order_record(
            &merchant,
            &mut product,
            &escrow_obj,
            1u32,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(merchant);
        test_scenario::return_shared(product);
        test_scenario::return_shared(escrow_obj);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ========================================================
    // Purchase Offer Reject / Withdraw Security Tests
    // ========================================================

    // Seller can reject a pending offer.
    #[test]
    fun test_purchase_offer_reject_success() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(MERCHANT);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        marketplace::reject_purchase_offer(
            &mut offer,
            test_scenario::ctx(&mut scenario),
        );

        assert!(!marketplace::purchase_offer_active(&offer), 0);

        test_scenario::return_shared(offer);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Attacker cannot reject someone else's offer.
    #[test]
    #[expected_failure(
        abort_code = 0,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_unauthorized_reject() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(ATTACKER);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        marketplace::reject_purchase_offer(
            &mut offer,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(offer);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Seller cannot reject twice.
    #[test]
    #[expected_failure(
        abort_code = 36,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_double_reject() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(MERCHANT);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        marketplace::reject_purchase_offer(
            &mut offer,
            test_scenario::ctx(&mut scenario),
        );

        marketplace::reject_purchase_offer(
            &mut offer,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(offer);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Buyer can withdraw a pending offer.
    #[test]
    fun test_purchase_offer_withdraw_success() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(BUYER);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        let mut escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);

        marketplace::withdraw_purchase_offer(
            &mut offer,
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        assert!(!marketplace::purchase_offer_active(&offer), 0);

        test_scenario::return_shared(offer);
        test_scenario::return_shared(escrow_obj);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Seller cannot withdraw buyer's offer.
    #[test]
    #[expected_failure(
        abort_code = 0,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_unauthorized_withdraw() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(MERCHANT);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        let mut escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);

        marketplace::withdraw_purchase_offer(
            &mut offer,
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(offer);
        test_scenario::return_shared(escrow_obj);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Buyer cannot withdraw twice.
    #[test]
    #[expected_failure(
        abort_code = 36,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_double_withdraw() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(BUYER);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        let mut escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);

        marketplace::withdraw_purchase_offer(
            &mut offer,
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        marketplace::withdraw_purchase_offer(
            &mut offer,
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(offer);
        test_scenario::return_shared(escrow_obj);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Buyer can withdraw after seller rejects and receive a refund.
    #[test]
    fun test_purchase_offer_withdraw_after_reject() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(MERCHANT);

        {
            let mut offer =
                test_scenario::take_shared<marketplace::PurchaseOffer>(
                    &scenario
                );

        let mut escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);

            marketplace::reject_purchase_offer(
                &mut offer,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(offer);
        test_scenario::return_shared(escrow_obj);
        };

        scenario.next_tx(BUYER);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        let mut escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);

        marketplace::withdraw_purchase_offer(
            &mut offer,
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(offer);
        test_scenario::return_shared(escrow_obj);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // Seller cannot reject after buyer withdraws.
    #[test]
    #[expected_failure(
        abort_code = 36,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_reject_after_withdraw() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(BUYER);

        {
            let mut offer =
                test_scenario::take_shared<marketplace::PurchaseOffer>(
                    &scenario
                );

        let mut escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);

            marketplace::withdraw_purchase_offer(
                &mut offer,
            &mut escrow_obj,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(offer);
        test_scenario::return_shared(escrow_obj);
        };

        scenario.next_tx(MERCHANT);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        let mut escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);

        marketplace::reject_purchase_offer(
            &mut offer,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(offer);
        test_scenario::return_shared(escrow_obj);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_purchase_offer_reject_and_buyer_refund() {
        let mut scenario = test_scenario::begin(MERCHANT);

        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);

        // Seller rejects the offer.
        scenario.next_tx(MERCHANT);

        {
            let mut offer =
                test_scenario::take_shared<marketplace::PurchaseOffer>(
                    &scenario
                );

            marketplace::reject_purchase_offer(
                &mut offer,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                !marketplace::purchase_offer_active(&offer),
                0
            );

            test_scenario::return_shared(offer);
        };

        // Buyer claims refund.
        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<escrow::Escrow>(
                    &scenario
                );

            assert!(
                escrow::deposited_a(&escrow_obj) == 880_000_000u64,
                1
            );

            escrow::withdraw_before_complete(
                &mut escrow_obj,
                test_scenario::ctx(&mut scenario),
            );

            assert!(escrow::status(&escrow_obj) == 4u8, 2);
            assert!(escrow::deposited_a(&escrow_obj) == 0, 3);
            assert!(escrow::vault_balance(&escrow_obj) == 0, 4);

            test_scenario::return_shared(escrow_obj);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(
        abort_code = 36,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_reject_after_accept() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(MERCHANT);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant = test_scenario::take_shared<
                marketplace::MerchantProfile
            >(&scenario);

            let mut product = test_scenario::take_shared<
                marketplace::Product
            >(&scenario);

            let mut offer = test_scenario::take_shared<
                marketplace::PurchaseOffer
            >(&scenario);

            let mut escrow_obj = test_scenario::take_shared<
                escrow::Escrow
            >(&scenario);

            let seller_coin = coin::mint_for_testing<SUI>(
                80_000_000u64,
                test_scenario::ctx(&mut scenario),
            );
            escrow::deposit(
                &mut escrow_obj,
                seller_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );
            assert!(escrow::status(&escrow_obj) == 1u8, 990);

            marketplace::accept_purchase_offer(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        scenario.next_tx(MERCHANT);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        marketplace::reject_purchase_offer(
            &mut offer,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(offer);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(
        abort_code = 36,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_withdraw_after_accept() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);
        scenario.next_tx(MERCHANT);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant = test_scenario::take_shared<
                marketplace::MerchantProfile
            >(&scenario);

            let mut product = test_scenario::take_shared<
                marketplace::Product
            >(&scenario);

            let mut offer = test_scenario::take_shared<
                marketplace::PurchaseOffer
            >(&scenario);

            let mut escrow_obj = test_scenario::take_shared<
                escrow::Escrow
            >(&scenario);

            let seller_coin = coin::mint_for_testing<SUI>(
                80_000_000u64,
                test_scenario::ctx(&mut scenario),
            );
            escrow::deposit(
                &mut escrow_obj,
                seller_coin,
                &clock,
                test_scenario::ctx(&mut scenario),
            );
            assert!(escrow::status(&escrow_obj) == 1u8, 990);

            marketplace::accept_purchase_offer(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        scenario.next_tx(BUYER);

        let mut offer =
            test_scenario::take_shared<marketplace::PurchaseOffer>(
                &scenario
            );

        let mut escrow_obj = test_scenario::take_shared<escrow::Escrow>(&scenario);

        marketplace::withdraw_purchase_offer(
            &mut offer,
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(offer);
        test_scenario::return_shared(escrow_obj);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(
        abort_code = 16,
        location = solzaar_sui::marketplace
    )]
    fun test_purchase_offer_accept_after_escrow_refund() {
        let mut scenario = test_scenario::begin(MERCHANT);
        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);

        // Buyer refunds directly through escrow.
        // PurchaseOffer remains active.
        scenario.next_tx(BUYER);

        {
            let mut escrow_obj =
                test_scenario::take_shared<escrow::Escrow>(
                    &scenario
                );

            escrow::withdraw_before_complete(
                &mut escrow_obj,
                test_scenario::ctx(&mut scenario),
            );

            assert!(escrow::status(&escrow_obj) == 4u8, 1);

            test_scenario::return_shared(escrow_obj);
        };

        // Seller attempts to accept the stale offer.
        scenario.next_tx(MERCHANT);

        {
            let mut registry = test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

            let merchant = test_scenario::take_shared<
                marketplace::MerchantProfile
            >(&scenario);

            let mut product = test_scenario::take_shared<
                marketplace::Product
            >(&scenario);

            let mut offer = test_scenario::take_shared<
                marketplace::PurchaseOffer
            >(&scenario);

            let escrow_obj = test_scenario::take_shared<
                escrow::Escrow
            >(&scenario);

            assert!(marketplace::purchase_offer_active(&offer), 2);

            marketplace::accept_purchase_offer(
                &mut registry,
                &merchant,
                &mut product,
                &mut offer,
                &escrow_obj,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(merchant);
            test_scenario::return_shared(product);
            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
            test_scenario::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_purchase_offer_withdraw_and_refund() {
        let mut scenario = test_scenario::begin(MERCHANT);

        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        setup_funded_purchase_offer(&mut scenario, &clock);

        scenario.next_tx(BUYER);

        {
            let mut offer =
                test_scenario::take_shared<marketplace::PurchaseOffer>(
                    &scenario
                );

            let mut escrow_obj =
                test_scenario::take_shared<escrow::Escrow>(
                    &scenario
                );

            assert!(
                escrow::vault_balance(&escrow_obj) ==
                    880_000_000u64,
                1
            );

            marketplace::withdraw_purchase_offer(
                &mut offer,
                &mut escrow_obj,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                !marketplace::purchase_offer_active(&offer),
                2
            );

            assert!(
                escrow::status(&escrow_obj) == 4u8,
                3
            );

            assert!(
                escrow::deposited_a(&escrow_obj) == 0,
                4
            );

            assert!(
                escrow::vault_balance(&escrow_obj) == 0,
                5
            );

            test_scenario::return_shared(offer);
            test_scenario::return_shared(escrow_obj);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // SECURITY: One escrow cannot create two PurchaseOffers.
    #[test]
    #[expected_failure(
        abort_code = 40,
        location = solzaar_sui::marketplace
    )]
    fun test_security_same_escrow_two_purchase_offers_rejected() {
        let mut scenario = test_scenario::begin(MERCHANT);

        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        // Creates the first funded PurchaseOffer.
        // The escrow is now permanently registered.
        setup_funded_purchase_offer(&mut scenario, &clock);

        // Buyer attempts to reuse the same escrow.
        scenario.next_tx(BUYER);

        let mut registry =
            test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(&scenario);

        let merchant =
            test_scenario::take_shared<
                marketplace::MerchantProfile
            >(&scenario);

        let product =
            test_scenario::take_shared<
                marketplace::Product
            >(&scenario);

        let escrow_obj =
            test_scenario::take_shared<
                escrow::Escrow
            >(&scenario);

        // Must abort with E_ESCROW_ALREADY_BOUND (40).
        marketplace::create_purchase_offer_v2(
                &mut registry,
            &merchant,
            &product,
            &escrow_obj,
            800_000_000u64,
            1u32,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // These lines must never execute.
        test_scenario::return_shared(registry);
        test_scenario::return_shared(merchant);
        test_scenario::return_shared(product);
        test_scenario::return_shared(escrow_obj);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

}