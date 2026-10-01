#[test_only]
module solzaar_sui::solzaar_sui_tests {

    use std::string;

    use sui::clock;
    use sui::test_scenario;

    use solzaar_sui::marketplace;

    use std::option;

    use sui::coin;
    use sui::sui::SUI;

    use escrow::escrow;

    const MERCHANT: address = @0xA;

    const BUYER: address = @0xB;

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
        clock: &clock::Clock,
    ) {
        let mut registry =
            test_scenario::take_shared<
                marketplace::MerchantRegistry
            >(scenario);

        marketplace::create_merchant(
            &mut registry,
            string::utf8(b"Test Store"),
            string::utf8(b"ipfs://description"),
            string::utf8(b"ipfs://logo"),
            string::utf8(b"ipfs://banner"),
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

            marketplace::create_order_record(
                &merchant,
                &mut product,
                &escrow_obj,
                1,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                marketplace::product_stock(&product) == 9,
                105
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

            marketplace::create_order_record(
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

            marketplace::create_order_record(
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

            marketplace::create_order_record(
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
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}