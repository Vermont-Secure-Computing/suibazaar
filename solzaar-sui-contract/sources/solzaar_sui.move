module solzaar_sui::marketplace {

    use std::string::String;
    use std::vector;

    use sui::clock::{Self, Clock};
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::dynamic_field;

    use std::option;

    use escrow::escrow::{Self, Escrow};

    // ============================================================
    // Errors
    // ============================================================

    const E_UNAUTHORIZED: u64 = 0;
    const E_TEXT_TOO_LONG: u64 = 1;
    const E_INVALID_PRICE: u64 = 2;
    const E_MERCHANT_INACTIVE: u64 = 3;
    const E_TOO_MANY_IMAGES: u64 = 4;
    const E_INVALID_IMAGE_URI: u64 = 5;
    const E_PRODUCT_DELETED: u64 = 6;
    const E_INVALID_DEPOSIT_PERCENT: u64 = 7;
    const E_INVALID_QUANTITY: u64 = 8;
    const E_INSUFFICIENT_STOCK: u64 = 9;
    const E_NOT_SOLZAAR_ESCROW: u64 = 10;
    const E_INVALID_ESCROW_PARTIES: u64 = 11;
    const E_INVALID_ORDER_AMOUNT: u64 = 12;
    const E_BUYER_DEPOSIT_INCOMPLETE: u64 = 13;
    const E_INVALID_SELLER_DEPOSIT: u64 = 14;
    const E_INVALID_BUYER_DEPOSIT: u64 = 15;
    const E_INVALID_ORDER_STATUS: u64 = 16;
    const E_MATH_OVERFLOW: u64 = 17;
    const E_SALE_ALREADY_RECORDED: u64 = 18;
    const E_STOCK_ALREADY_RESTORED: u64 = 19;
    const E_MERCHANT_ALREADY_EXISTS: u64 = 20;
    const E_INVALID_RATING: u64 = 21;
    const E_REVIEW_TOO_LONG: u64 = 22;
    const E_ORDER_NOT_COMPLETED: u64 = 23;
    const E_ONLY_BUYER_CAN_REVIEW: u64 = 24;
    const E_INVALID_REVIEW_PRODUCT: u64 = 25;
    const E_INVALID_REVIEW_MERCHANT: u64 = 26;
    const E_ORDER_ALREADY_REVIEWED: u64 = 27;
    const E_EMPTY_MESSAGE: u64 = 28;
    const E_MESSAGE_TOO_LONG: u64 = 29;
    const E_INVALID_SPECIAL_PRICE: u64 = 30;
    const E_SPECIAL_OFFER_INACTIVE: u64 = 32;
    const E_SPECIAL_OFFER_BUYER_MISMATCH: u64 = 33;
    const E_SPECIAL_OFFER_PRODUCT_MISMATCH: u64 = 34;
    const E_PURCHASE_OFFER_INACTIVE: u64 = 36;
    const E_PURCHASE_OFFER_PRODUCT_MISMATCH: u64 = 38;
    const E_PURCHASE_OFFER_ESCROW_MISMATCH: u64 = 39;
    const E_ESCROW_ALREADY_BOUND: u64 = 40;
    const E_LEGACY_CHECKOUT_DISABLED: u64 = 41;
    const E_CANCELLATION_REASON_EMPTY: u64 = 42;
    const E_CANCELLATION_REASON_TOO_LONG: u64 = 43;

    // ============================================================
    // Limits
    // ============================================================

    const MAX_STORE_NAME: u64 = 64;
    const MAX_DESCRIPTION_URI: u64 = 200;
    const MAX_LOGO_URI: u64 = 200;
    const MAX_BANNER_URI: u64 = 200;
    const MAX_SHIPS_FROM: u64 = 64;
    const MAX_CONTACT: u64 = 300;

    const MAX_PRODUCT_TITLE: u64 = 64;
    const MAX_PRODUCT_DESCRIPTION_URI: u64 = 200;
    const MAX_PRODUCT_IMAGES: u64 = 3;
    const MAX_IMAGE_URI: u64 = 250;
    const MAX_CATEGORY: u64 = 32;

    const MAX_BPS: u64 = 10_000;
    const MAX_REVIEW_COMMENT: u64 = 280;
    const MAX_MESSAGE_LENGTH: u64 = 280;

    // ============================================================
    // Merchant Registry
    // ============================================================

    public struct MerchantRegistry has key {
        id: UID,
        merchants: Table<address, ID>,
    }

    // ============================================================
    // Merchant
    // ============================================================

    public struct MerchantProfile has key {
        id: UID,

        authority: address,

        store_name: String,
        description_uri: String,
        logo_uri: String,
        banner_uri: String,
        ships_from: String,
        preferred_contact: String,

        seller_deposit_bps: u16,
        total_sold: u32,

        active: bool,
        verified: bool,

        created_at: u64,
    }

    // ============================================================
    // Product
    // ============================================================

    public struct Product has key {
        id: UID,

        merchant: address,
        product_id: u64,

        title: String,
        description_uri: String,
        image_uris: vector<String>,
        category: String,

        price: u64,
        seller_deposit_bps_override: option::Option<u16>,
        stock: u32,
        sold: u32,

        active: bool,
        deleted: bool,

        created_at: u64,
        updated_at: u64,
    }

    public struct OrderRecord has key {
        id: UID,

        escrow: ID,
        product: ID,

        buyer: address,
        seller: address,

        quantity: u32,
        unit_price: u64,
        total_price: u64,
        security_deposit: u64,

        completed_sale_recorded: bool,
        stock_restored: bool,
        reviewed: bool,

        created_at: u64,
    }

    // ============================================================
    // Reviews / Reputation
    // ============================================================

    public struct MerchantReputation has key {
        id: UID,

        merchant: address,

        total_reviews: u64,
        total_rating: u64,

        five_star: u64,
        four_star: u64,
        three_star: u64,
        two_star: u64,
        one_star: u64,
    }

    public struct ProductReview has key {
        id: UID,

        order: ID,
        escrow: ID,
        product: ID,

        merchant: address,
        reviewer: address,

        rating: u8,
        comment: String,

        created_at: u64,
    }


    // ============================================================
    // Events
    // ============================================================

    public struct MerchantCreated has copy, drop {
        merchant_id: ID,
        authority: address,
    }

    public struct MerchantUpdated has copy, drop {
        merchant_id: ID,
        authority: address,
    }

    public struct ProductCreated has copy, drop {
        product_object_id: ID,
        merchant: address,
        product_id: u64,
    }

    public struct ProductUpdated has copy, drop {
        product_object_id: ID,
        merchant: address,
        product_id: u64,
    }

    public struct ProductDeleted has copy, drop {
        product_object_id: ID,
        merchant: address,
        product_id: u64,
    }

    public struct OrderCreated has copy, drop {
        order_id: ID,
        escrow_id: ID,
        product_id: ID,

        buyer: address,
        seller: address,

        quantity: u32,
        total_price: u64,
    }

    public struct ReputationCreated has copy, drop {
        reputation_id: ID,
        merchant: address,
    }

    public struct ReviewCreated has copy, drop {
        review_id: ID,
        order_id: ID,
        escrow_id: ID,
        product_id: ID,
        merchant: address,
        reviewer: address,
        rating: u8,
    }

    public struct ChatMessage has key {
        id: UID,

        product: ID,
        buyer: address,
        seller: address,

        sender: address,
        recipient: address,

        message: String,
        created_at: u64,
    }

    public struct SpecialPriceOffer has key {
        id: UID,

        product: ID,
        seller: address,
        buyer: address,

        unit_price: u64,
        quantity: u32,

        active: bool,
        used: bool,

        created_at: u64,
    }

    public struct SpecialPriceOffered has copy, drop {
        offer_id: ID,
        product: ID,

        seller: address,
        buyer: address,

        unit_price: u64,
        quantity: u32,
    }

    public struct SpecialPriceOfferCancelled has copy, drop {
        offer_id: ID,
        product: ID,
        seller: address,
        buyer: address,
    }

        // ============================================================
    // Buyer-Funded Purchase Offer
    // ============================================================

    public struct PurchaseOffer has key {
        id: UID,

        product: ID,
        escrow: ID,

        buyer: address,
        seller: address,

        unit_price: u64,
        quantity: u32,
        total_price: u64,
        security_deposit: u64,
        buyer_deposit: u64,

        active: bool,
        accepted: bool,
        rejected: bool,
        withdrawn: bool,

        created_at: u64,
    }

    public struct PurchaseOfferCreated has copy, drop {
        offer_id: ID,
        product: ID,
        escrow: ID,

        buyer: address,
        seller: address,

        unit_price: u64,
        quantity: u32,
        total_price: u64,
        buyer_deposit: u64,

    }

    public struct PurchaseOfferAccepted has copy, drop {
        offer_id: ID,
        product: ID,
        escrow: ID,
        buyer: address,
        seller: address,
    }

    public struct PurchaseOfferRejected has copy, drop {
        offer_id: ID,
        product: ID,
        escrow: ID,
        buyer: address,
        seller: address,
    }

    public struct PurchaseOfferWithdrawn has copy, drop {
        offer_id: ID,
        product: ID,
        escrow: ID,
        buyer: address,
        seller: address,
    }

    public struct MessageSent has copy, drop {
        message_id: ID,
        product: ID,

        buyer: address,
        seller: address,

        sender: address,
        recipient: address,

        created_at: u64,
    }

    // ============================================================
    // Module Initialization
    // ============================================================

    fun init(ctx: &mut TxContext) {
        let registry = MerchantRegistry {
            id: object::new(ctx),
            merchants: table::new(ctx),
        };

        transfer::share_object(registry);
    }

    #[test_only]
    public fun create_registry_for_testing(
        ctx: &mut TxContext,
    ) {
        let registry = MerchantRegistry {
            id: object::new(ctx),
            merchants: table::new(ctx),
        };

        transfer::share_object(registry);
    }

    // ============================================================
    // Create Merchant
    // ============================================================

    public fun create_merchant(
        registry: &mut MerchantRegistry,
        store_name: String,
        description_uri: String,
        logo_uri: String,
        banner_uri: String,
        ships_from: String,
        seller_deposit_bps: u16,
        preferred_contact: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(
            store_name.length() <= MAX_STORE_NAME,
            E_TEXT_TOO_LONG
        );

        assert!(
            description_uri.length() <= MAX_DESCRIPTION_URI,
            E_TEXT_TOO_LONG
        );

        assert!(
            logo_uri.length() <= MAX_LOGO_URI,
            E_TEXT_TOO_LONG
        );

        assert!(
            banner_uri.length() <= MAX_BANNER_URI,
            E_TEXT_TOO_LONG
        );

        assert!(
            ships_from.length() <= MAX_SHIPS_FROM,
            E_TEXT_TOO_LONG
        );

        assert!(
            preferred_contact.length() <= MAX_CONTACT,
            E_TEXT_TOO_LONG
        );

        assert!(
            (seller_deposit_bps as u64) <= MAX_BPS,
            E_INVALID_DEPOSIT_PERCENT
        );

        let authority = tx_context::sender(ctx);

        // One wallet/address may create only one merchant.
        assert!(
            !table::contains(
                &registry.merchants,
                authority
            ),
            E_MERCHANT_ALREADY_EXISTS
        );

        let merchant = MerchantProfile {
            id: object::new(ctx),

            authority,

            store_name,
            description_uri,
            logo_uri,
            banner_uri,
            ships_from,
            preferred_contact,

            seller_deposit_bps,
            total_sold: 0,

            active: true,
            verified: false,

            created_at: clock::timestamp_ms(clock),
        };

        let merchant_id =
            object::uid_to_inner(&merchant.id);

        let reputation = MerchantReputation {
            id: object::new(ctx),

            merchant: authority,

            total_reviews: 0,
            total_rating: 0,

            five_star: 0,
            four_star: 0,
            three_star: 0,
            two_star: 0,
            one_star: 0,
        };

        let reputation_id =
            object::uid_to_inner(&reputation.id);

        // Permanently bind this wallet to its merchant.
        table::add(
            &mut registry.merchants,
            authority,
            merchant_id,
        );

        event::emit(MerchantCreated {
            merchant_id,
            authority,
        });

        event::emit(ReputationCreated {
            reputation_id,
            merchant: authority,
        });

        transfer::share_object(merchant);
        transfer::share_object(reputation);
    }

    // ============================================================
    // Update Merchant
    // ============================================================

    public fun update_merchant(
        merchant: &mut MerchantProfile,

        store_name: String,
        description_uri: String,
        logo_uri: String,
        banner_uri: String,
        ships_from: String,
        seller_deposit_bps: u16,
        preferred_contact: String,
        active: bool,

        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(
            sender == merchant.authority,
            E_UNAUTHORIZED
        );

        assert!(
            store_name.length() <= MAX_STORE_NAME,
            E_TEXT_TOO_LONG
        );

        assert!(
            description_uri.length() <= MAX_DESCRIPTION_URI,
            E_TEXT_TOO_LONG
        );

        assert!(
            logo_uri.length() <= MAX_LOGO_URI,
            E_TEXT_TOO_LONG
        );

        assert!(
            banner_uri.length() <= MAX_BANNER_URI,
            E_TEXT_TOO_LONG
        );

        assert!(
            ships_from.length() <= MAX_SHIPS_FROM,
            E_TEXT_TOO_LONG
        );

        assert!(
            preferred_contact.length() <= MAX_CONTACT,
            E_TEXT_TOO_LONG
        );

        assert!(
            (seller_deposit_bps as u64) <= MAX_BPS,
            E_INVALID_DEPOSIT_PERCENT
        );

        merchant.store_name = store_name;
        merchant.description_uri = description_uri;
        merchant.logo_uri = logo_uri;
        merchant.banner_uri = banner_uri;
        merchant.ships_from = ships_from;
        merchant.seller_deposit_bps =
            seller_deposit_bps;
        merchant.preferred_contact =
            preferred_contact;
        merchant.active = active;

        event::emit(MerchantUpdated {
            merchant_id:
                object::uid_to_inner(&merchant.id),
            authority: sender,
        });
    }

    // ============================================================
    // Create Product
    // ============================================================

    public fun create_product(
        merchant: &MerchantProfile,

        product_id: u64,
        title: String,
        description_uri: String,
        image_uris: vector<String>,
        category: String,
        price: u64,
        stock: u32,
        seller_deposit_bps_override: option::Option<u16>,

        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(
            sender == merchant.authority,
            E_UNAUTHORIZED
        );

        assert!(
            merchant.active,
            E_MERCHANT_INACTIVE
        );

        validate_product_fields(
            &title,
            &description_uri,
            &image_uris,
            &category,
            price,
        );

        validate_deposit_override(&seller_deposit_bps_override);

        let now =
            clock::timestamp_ms(clock);

        let product = Product {
            id: object::new(ctx),

            merchant: sender,
            product_id,

            title,
            description_uri,
            image_uris,
            category,

            price,
            seller_deposit_bps_override,
            stock,
            sold: 0,

            active: true,
            deleted: false,

            created_at: now,
            updated_at: now,
        };

        let product_object_id =
            object::uid_to_inner(&product.id);

        event::emit(ProductCreated {
            product_object_id,
            merchant: sender,
            product_id,
        });

        transfer::share_object(product);
    }

    // ============================================================
    // Update Product
    // ============================================================

    public fun update_product(
        product: &mut Product,

        title: String,
        description_uri: String,
        image_uris: vector<String>,
        category: String,
        price: u64,
        stock: u32,
        active: bool,
        seller_deposit_bps_override: option::Option<u16>,

        clock: &Clock,
        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(
            sender == product.merchant,
            E_UNAUTHORIZED
        );

        assert!(
            !product.deleted,
            E_PRODUCT_DELETED
        );

        validate_product_fields(
            &title,
            &description_uri,
            &image_uris,
            &category,
            price,
        );

        validate_deposit_override(&seller_deposit_bps_override);

        product.title = title;
        product.description_uri =
            description_uri;
        product.image_uris = image_uris;
        product.category = category;
        product.price = price;
        product.seller_deposit_bps_override = seller_deposit_bps_override;
        product.stock = stock;
        product.active = active;

        product.updated_at =
            clock::timestamp_ms(clock);

        event::emit(ProductUpdated {
            product_object_id:
                object::uid_to_inner(&product.id),
            merchant: sender,
            product_id: product.product_id,
        });
    }

    // ============================================================
    // Delete Product
    // ============================================================

    public fun delete_product(
        product: &mut Product,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(
            sender == product.merchant,
            E_UNAUTHORIZED
        );

        assert!(
            !product.deleted,
            E_PRODUCT_DELETED
        );

        product.active = false;
        product.deleted = true;

        product.updated_at =
            clock::timestamp_ms(clock);

        event::emit(ProductDeleted {
            product_object_id:
                object::uid_to_inner(&product.id),
            merchant: sender,
            product_id: product.product_id,
        });
    }

    // ============================================================
    // Product Validation
    // ============================================================

    fun validate_product_fields(
        title: &String,
        description_uri: &String,
        image_uris: &vector<String>,
        category: &String,
        price: u64,
    ) {
        assert!(
            title.length() <= MAX_PRODUCT_TITLE,
            E_TEXT_TOO_LONG
        );

        assert!(
            description_uri.length()
                <= MAX_PRODUCT_DESCRIPTION_URI,
            E_TEXT_TOO_LONG
        );

        assert!(
            vector::length(image_uris)
                <= MAX_PRODUCT_IMAGES,
            E_TOO_MANY_IMAGES
        );

        let mut i = 0;

        while (i < vector::length(image_uris)) {
            let image_uri =
                vector::borrow(image_uris, i);

            assert!(
                image_uri.length() > 0,
                E_INVALID_IMAGE_URI
            );

            assert!(
                image_uri.length()
                    <= MAX_IMAGE_URI,
                E_TEXT_TOO_LONG
            );

            i = i + 1;
        };

        assert!(
            category.length() <= MAX_CATEGORY,
            E_TEXT_TOO_LONG
        );

        assert!(
            price > 0,
            E_INVALID_PRICE
        );
    }

    // ============================================================
    // Create Order Record
    // ============================================================

    // Legacy V1 entry point.
    // Disabled to prevent bypassing escrow reuse protection.
    public fun create_order_record(
        _merchant: &MerchantProfile,
        _product: &mut Product,
        _escrow_object: &Escrow,
        _quantity: u32,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ) {
        abort E_LEGACY_CHECKOUT_DISABLED
    }

    public fun create_order_record_v2(
        registry: &mut MerchantRegistry,
        merchant: &MerchantProfile,
        product: &mut Product,
        escrow_object: &Escrow,
        quantity: u32,
        clock: &Clock,
        ctx: &mut TxContext,
        
    ) {
        let buyer = tx_context::sender(ctx);
        let seller = product.merchant;

        // --------------------------------------------------------
        // Merchant / Product validation
        // --------------------------------------------------------

        assert!(
            merchant.authority == seller,
            E_UNAUTHORIZED
        );

        assert!(
            merchant.active,
            E_MERCHANT_INACTIVE
        );

        assert!(
            product.active,
            E_PRODUCT_DELETED
        );

        assert!(
            !product.deleted,
            E_PRODUCT_DELETED
        );

        assert!(
            quantity > 0,
            E_INVALID_QUANTITY
        );

        assert!(
            product.stock >= quantity,
            E_INSUFFICIENT_STOCK
        );

        // --------------------------------------------------------
        // Calculate order amount
        // --------------------------------------------------------

        let quantity_u64 = quantity as u64;

        let total_price =
            checked_mul(
                product.price,
                quantity_u64
            );

        let deposit_numerator =
            checked_mul(
                total_price,
                effective_deposit_bps(product, merchant)
            );

        let mut security_deposit =
            deposit_numerator / 10_000;

        // Same behavior as Solana contract:
        // minimum seller security deposit is 1 MIST.
        if (security_deposit == 0) {
            security_deposit = 1;
        };

        let expected_buyer_deposit =
            checked_add_u64(
                total_price,
                security_deposit
            );

        // --------------------------------------------------------
        // Escrow validation
        // --------------------------------------------------------

        assert!(
            escrow::status(escrow_object) == 0,
            E_INVALID_ORDER_STATUS
        );

        assert!(
            escrow::creator(escrow_object) == buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            contains_solzaar_marker(
                escrow::note(escrow_object)
            ),
            E_NOT_SOLZAAR_ESCROW
        );

                let party_a =
            escrow::party_a_address(escrow_object);

        let party_b =
            escrow::party_b_address(escrow_object);

        assert!(
            party_a == buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            party_b == seller,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            party_a != party_b,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            escrow::reference_amount(escrow_object)
                == total_price,
            E_INVALID_ORDER_AMOUNT
        );

        assert!(
            escrow::required_deposit_a(escrow_object)
                == expected_buyer_deposit,
            E_INVALID_BUYER_DEPOSIT
        );

        assert!(
            escrow::deposited_a(escrow_object)
                == expected_buyer_deposit,
            E_BUYER_DEPOSIT_INCOMPLETE
        );

        assert!(
            escrow::required_deposit_b(escrow_object)
                == security_deposit,
            E_INVALID_SELLER_DEPOSIT
        );

        // --------------------------------------------------------
        // Reserve stock
        // --------------------------------------------------------

        product.stock =
            product.stock - quantity;

        product.updated_at =
            clock::timestamp_ms(clock);

        // --------------------------------------------------------
        // Create immutable order record
        // --------------------------------------------------------

        let order = OrderRecord {
            id: object::new(ctx),

            escrow:
                object::id(escrow_object),

            product:
                object::id(product),

            buyer,
            seller,

            quantity,
            unit_price: product.price,
            total_price,
            security_deposit,

            completed_sale_recorded: false,
            stock_restored: false,
            reviewed: false,

            created_at:
                clock::timestamp_ms(clock),
        };

        let order_id =
            object::uid_to_inner(&order.id);

        event::emit(OrderCreated {
            order_id,

            escrow_id:
                object::id(escrow_object),

            product_id:
                object::id(product),

            buyer,
            seller,

            quantity,
            total_price,
        });

         bind_escrow(
            registry,
            object::id(escrow_object),
        );

        transfer::share_object(order);
    }

        // ============================================================
    // Create Special Price Order Record
    // ============================================================

    public fun create_special_order_record(
        registry: &mut MerchantRegistry,
        merchant: &MerchantProfile,
        product: &mut Product,
        offer: &mut SpecialPriceOffer,
        escrow_object: &Escrow,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let buyer = tx_context::sender(ctx);
        let seller = product.merchant;
        let now = clock::timestamp_ms(clock);

        // --------------------------------------------------------
        // Merchant / Product validation
        // --------------------------------------------------------

        assert!(
            merchant.authority == seller,
            E_UNAUTHORIZED
        );

        assert!(
            merchant.active,
            E_MERCHANT_INACTIVE
        );

        assert!(
            product.active,
            E_PRODUCT_DELETED
        );

        assert!(
            !product.deleted,
            E_PRODUCT_DELETED
        );

        // --------------------------------------------------------
        // Special offer validation
        // --------------------------------------------------------

        // Offer must belong to this exact product.
        assert!(
            offer.product == object::id(product),
            E_SPECIAL_OFFER_PRODUCT_MISMATCH
        );

        // Offer seller must still be the product seller.
        assert!(
            offer.seller == seller,
            E_UNAUTHORIZED
        );

        // Only the buyer named in the offer may use it.
        assert!(
            offer.buyer == buyer,
            E_SPECIAL_OFFER_BUYER_MISMATCH
        );

        // Cancelled / disabled offer cannot be used.
        assert!(
            offer.active,
            E_SPECIAL_OFFER_INACTIVE
        );

        // One-time use only.
        assert!(
            !offer.used,
            E_SPECIAL_OFFER_INACTIVE
        );

        // No expiration check: cancellation and one-time-use protections apply.
        // No automatic expiration; status and authorization checks remain.

        assert!(
            offer.unit_price > 0,
            E_INVALID_SPECIAL_PRICE
        );

        assert!(
            offer.quantity > 0,
            E_INVALID_QUANTITY
        );

        assert!(
            product.stock >= offer.quantity,
            E_INSUFFICIENT_STOCK
        );

        // --------------------------------------------------------
        // Calculate negotiated order amount
        // --------------------------------------------------------

        let quantity = offer.quantity;
        let unit_price = offer.unit_price;
        let quantity_u64 = quantity as u64;

        let total_price =
            checked_mul(
                unit_price,
                quantity_u64
            );

        let deposit_numerator =
            checked_mul(
                total_price,
                effective_deposit_bps(product, merchant)
            );

        let mut security_deposit =
            deposit_numerator / 10_000;

        // Same behavior as normal Solzaar order:
        // minimum seller security deposit is 1 MIST.
        if (security_deposit == 0) {
            security_deposit = 1;
        };

        let expected_buyer_deposit =
            checked_add_u64(
                total_price,
                security_deposit
            );

        // --------------------------------------------------------
        // Escrow validation
        // --------------------------------------------------------

        assert!(
            escrow::status(escrow_object) == 0,
            E_INVALID_ORDER_STATUS
        );

        assert!(
            escrow::creator(escrow_object) == buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            contains_solzaar_marker(
                escrow::note(escrow_object)
            ),
            E_NOT_SOLZAAR_ESCROW
        );

        let party_a =
            escrow::party_a_address(escrow_object);

        let party_b =
            escrow::party_b_address(escrow_object);

        assert!(
            party_a == buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            party_b == seller,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            party_a != party_b,
            E_INVALID_ESCROW_PARTIES
        );

        // Escrow sale amount must match negotiated total exactly.
        assert!(
            escrow::reference_amount(escrow_object)
                == total_price,
            E_INVALID_ORDER_AMOUNT
        );

        assert!(
            escrow::required_deposit_a(escrow_object)
                == expected_buyer_deposit,
            E_INVALID_BUYER_DEPOSIT
        );

        assert!(
            escrow::deposited_a(escrow_object)
                == expected_buyer_deposit,
            E_BUYER_DEPOSIT_INCOMPLETE
        );

        assert!(
            escrow::required_deposit_b(escrow_object)
                == security_deposit,
            E_INVALID_SELLER_DEPOSIT
        );

        // --------------------------------------------------------
        // Consume offer + reserve stock
        // --------------------------------------------------------

        offer.used = true;
        offer.active = false;

        product.stock =
            product.stock - quantity;

        product.updated_at = now;

        // --------------------------------------------------------
        // Create immutable order record
        // --------------------------------------------------------

        let order = OrderRecord {
            id: object::new(ctx),

            escrow:
                object::id(escrow_object),

            product:
                object::id(product),

            buyer,
            seller,

            quantity,
            unit_price,
            total_price,
            security_deposit,

            completed_sale_recorded: false,
            stock_restored: false,
            reviewed: false,

            created_at: now,
        };

        let order_id =
            object::uid_to_inner(&order.id);

        event::emit(OrderCreated {
            order_id,

            escrow_id:
                object::id(escrow_object),

            product_id:
                object::id(product),

            buyer,
            seller,

            quantity,
            total_price,
        });

        bind_escrow(
            registry,
            object::id(escrow_object),
        );

        transfer::share_object(order);
    }

    // ============================================================
    // Record Completed Sale
    // ============================================================

    public fun record_completed_sale(
        merchant: &mut MerchantProfile,
        product: &mut Product,
        order: &mut OrderRecord,
        escrow_object: &Escrow,
    ) {
        // Escrow must belong to this order.
        assert!(
            order.escrow == object::id(escrow_object),
            E_INVALID_ORDER_STATUS
        );

        // Product must belong to this order.
        assert!(
            order.product == object::id(product),
            E_INVALID_ORDER_STATUS
        );

        // Seller relationships must still match.
        assert!(
            order.seller == product.merchant,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            merchant.authority == order.seller,
            E_INVALID_ESCROW_PARTIES
        );

        // Escrow must be completed.
        assert!(
            escrow::status(escrow_object) == 3,
            E_INVALID_ORDER_STATUS
        );

        // A completed mutual cancellation is not a sale.
        //
        // Mutual cancellation returns each party's full deposit:
        //   payout_a == deposited_a
        //   payout_b == deposited_b
        //   donation == 0
        //
        // Do not allow such an escrow to increment sold counters.
        let is_mutual_cancellation =
            escrow::proposed_payout_a(escrow_object)
                == escrow::deposited_a(escrow_object)
            &&
            escrow::proposed_payout_b(escrow_object)
                == escrow::deposited_b(escrow_object)
            &&
            escrow::proposed_donation(escrow_object) == 0;

        assert!(
            !is_mutual_cancellation,
            E_INVALID_ORDER_STATUS
        );

                // Escrow parties must still match the recorded order.
        let party_a =
            escrow::party_a_address(escrow_object);

        let party_b =
            escrow::party_b_address(escrow_object);

        assert!(
            party_a == order.buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            party_b == order.seller,
            E_INVALID_ESCROW_PARTIES
        );

        // Replay protection.
        assert!(
            !order.completed_sale_recorded,
            E_SALE_ALREADY_RECORDED
        );

        assert!(
            !order.stock_restored,
            E_STOCK_ALREADY_RESTORED
        );

        // Record sale.
        product.sold =
            checked_add_u32(
                product.sold,
                order.quantity
            );

        merchant.total_sold =
            checked_add_u32(
                merchant.total_sold,
                order.quantity
            );

        order.completed_sale_recorded = true;
    }


    // ============================================================
    // Restore Cancelled Order Stock
    // ============================================================

    public fun restore_cancelled_order_stock(
        product: &mut Product,
        order: &mut OrderRecord,
        escrow_object: &Escrow,
    ) {
        // Escrow must belong to this order.
        assert!(
            order.escrow == object::id(escrow_object),
            E_INVALID_ORDER_STATUS
        );

        // Product must belong to this order.
        assert!(
            order.product == object::id(product),
            E_INVALID_ORDER_STATUS
        );

        assert!(
            order.seller == product.merchant,
            E_INVALID_ESCROW_PARTIES
        );

        // Escrow must be cancelled.
        assert!(
            escrow::status(escrow_object) == 4,
            E_INVALID_ORDER_STATUS
        );

                let party_a =
            escrow::party_a_address(escrow_object);

        let party_b =
            escrow::party_b_address(escrow_object);

        assert!(
            party_a == order.buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            party_b == order.seller,
            E_INVALID_ESCROW_PARTIES
        );

        // Cannot restore twice or restore a completed sale.
        assert!(
            !order.stock_restored,
            E_STOCK_ALREADY_RESTORED
        );

        assert!(
            !order.completed_sale_recorded,
            E_INVALID_ORDER_STATUS
        );

        product.stock =
            checked_add_u32(
                product.stock,
                order.quantity
            );
        order.stock_restored = true;
    }

    // ============================================================
    // Restore Mutually Cancelled Order Stock
    // ============================================================

    public fun restore_mutually_cancelled_order_stock(
        product: &mut Product,
        order: &mut OrderRecord,
        escrow_object: &Escrow,
    ) {
        assert!(
            order.escrow == object::id(escrow_object),
            E_INVALID_ORDER_STATUS
        );

        assert!(
            order.product == object::id(product),
            E_INVALID_ORDER_STATUS
        );

        assert!(
            order.seller == product.merchant,
            E_INVALID_ESCROW_PARTIES
        );

        // Mutual cancellation uses normal finalization,
        // therefore the escrow ends as COMPLETED.
        assert!(
            escrow::status(escrow_object) == 3,
            E_INVALID_ORDER_STATUS
        );

        let party_a =
            escrow::party_a_address(escrow_object);

        let party_b =
            escrow::party_b_address(escrow_object);

        assert!(
            party_a == order.buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            party_b == order.seller,
            E_INVALID_ESCROW_PARTIES
        );

        // Exact full-refund finalization.
        assert!(
            escrow::proposed_payout_a(escrow_object)
                == escrow::deposited_a(escrow_object),
            E_INVALID_ORDER_STATUS
        );

        assert!(
            escrow::proposed_payout_b(escrow_object)
                == escrow::deposited_b(escrow_object),
            E_INVALID_ORDER_STATUS
        );

        assert!(
            escrow::proposed_donation(escrow_object) == 0,
            E_INVALID_ORDER_STATUS
        );

        assert!(
            !order.stock_restored,
            E_STOCK_ALREADY_RESTORED
        );

        assert!(
            !order.completed_sale_recorded,
            E_INVALID_ORDER_STATUS
        );

        product.stock =
            checked_add_u32(
                product.stock,
                order.quantity
            );
        order.stock_restored = true;
    }

    // ============================================================
    // Marketplace Mutual Cancellation (generic escrow adapter)
    // ============================================================

    fun assert_order_escrow_match(order: &OrderRecord, escrow_object: &Escrow) {
        assert!(order.escrow == object::id(escrow_object), E_INVALID_ORDER_STATUS);
        assert!(escrow::party_a_address(escrow_object) == order.buyer, E_INVALID_ESCROW_PARTIES);
        assert!(escrow::party_b_address(escrow_object) == order.seller, E_INVALID_ESCROW_PARTIES);
        assert!(!order.stock_restored, E_INVALID_ORDER_STATUS);
        assert!(!order.completed_sale_recorded, E_INVALID_ORDER_STATUS);
    }

    // Either party proposes a neutral refund. Generic escrow owns the funds.
    public fun request_mutual_cancellation(
        order: &OrderRecord,
        escrow_object: &mut Escrow,
        reason: vector<u8>,
        ctx: &TxContext,
    ) {
        assert_order_escrow_match(order, escrow_object);
        assert!(escrow::status(escrow_object) == 1, E_INVALID_ORDER_STATUS);
        assert!(vector::length(&reason) > 0, E_CANCELLATION_REASON_EMPTY);
        // Prefix plus reason must fit generic escrow's 200-byte note.
        assert!(vector::length(&reason) <= 180, E_CANCELLATION_REASON_TOO_LONG);
        let mut note = b"MUTUAL_CANCELLATION|";
        vector::append(&mut note, reason);
        let refund_a = escrow::deposited_a(escrow_object);
        let refund_b = escrow::deposited_b(escrow_object);
        escrow::suggest_finalization(
            escrow_object,
            refund_a,
            refund_b,
            0,
            note,
            ctx,
        );
    }

    // Approve and restore stock atomically in a single Sui transaction.
    public fun approve_mutual_cancellation(
        product: &mut Product,
        order: &mut OrderRecord,
        escrow_object: &mut Escrow,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert_order_escrow_match(order, escrow_object);
        assert!(order.product == object::id(product), E_INVALID_ORDER_STATUS);
        assert!(escrow::status(escrow_object) == 2, E_INVALID_ORDER_STATUS);
        assert!(escrow::proposed_payout_a(escrow_object) == escrow::deposited_a(escrow_object), E_INVALID_ORDER_STATUS);
        assert!(escrow::proposed_payout_b(escrow_object) == escrow::deposited_b(escrow_object), E_INVALID_ORDER_STATUS);
        assert!(escrow::proposed_donation(escrow_object) == 0, E_INVALID_ORDER_STATUS);
        escrow::accept_finalization(escrow_object, clock, ctx);
        restore_mutually_cancelled_order_stock(product, order, escrow_object);
    }

    // The generic escrow rejects the proposal and returns to deposits-complete.
    public fun decline_mutual_cancellation(
        order: &OrderRecord,
        escrow_object: &mut Escrow,
        ctx: &TxContext,
    ) {
        assert_order_escrow_match(order, escrow_object);
        assert!(escrow::status(escrow_object) == 2, E_INVALID_ORDER_STATUS);
        assert!(escrow::proposed_payout_a(escrow_object) == escrow::deposited_a(escrow_object), E_INVALID_ORDER_STATUS);
        assert!(escrow::proposed_payout_b(escrow_object) == escrow::deposited_b(escrow_object), E_INVALID_ORDER_STATUS);
        assert!(escrow::proposed_donation(escrow_object) == 0, E_INVALID_ORDER_STATUS);
        escrow::reject_finalization(escrow_object, ctx);
    }

    // ============================================================
    // Solzaar Escrow Marker
    // ============================================================

    fun contains_solzaar_marker(
        note: &vector<u8>,
    ): bool {
        let marker = b"\"marketplace\":\"solbazaar\"";

        let note_len = vector::length(note);
        let marker_len = vector::length(&marker);

        if (note_len < marker_len) {
            return false
        };

        let mut i = 0;

        while (i + marker_len <= note_len) {
            let mut j = 0;
            let mut matched = true;

            while (j < marker_len) {
                if (
                    *vector::borrow(note, i + j)
                        != *vector::borrow(&marker, j)
                ) {
                    matched = false;
                    j = marker_len;
                } else {
                    j = j + 1;
                };
            };

            if (matched) {
                return true
            };

            i = i + 1;
        };

        false
    }

    // ============================================================
    // Submit Product Review
    // ============================================================

    public fun submit_review(
        merchant: &MerchantProfile,
        product: &Product,
        order: &mut OrderRecord,
        escrow_object: &Escrow,
        reputation: &mut MerchantReputation,
        rating: u8,
        comment: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let reviewer = tx_context::sender(ctx);

        // Rating must be 1-5.
        assert!(
            rating >= 1 && rating <= 5,
            E_INVALID_RATING
        );

        // Comment max 280 bytes.
        assert!(
            comment.length() <= MAX_REVIEW_COMMENT,
            E_REVIEW_TOO_LONG
        );

        // Must be the buyer.
        assert!(
            reviewer == order.buyer,
            E_ONLY_BUYER_CAN_REVIEW
        );

        // Order must belong to this escrow.
        assert!(
            order.escrow == object::id(escrow_object),
            E_INVALID_ORDER_STATUS
        );

        // Order must belong to this product.
        assert!(
            order.product == object::id(product),
            E_INVALID_REVIEW_PRODUCT
        );

        // Product/order/merchant must agree on seller.
        assert!(
            order.seller == product.merchant,
            E_INVALID_REVIEW_MERCHANT
        );

        assert!(
            merchant.authority == order.seller,
            E_INVALID_REVIEW_MERCHANT
        );

        assert!(
            reputation.merchant == order.seller,
            E_INVALID_REVIEW_MERCHANT
        );

        // This must be a genuine completed sale.
        //
        // record_completed_sale() is deliberately required instead
        // of checking only escrow status == 3. A mutual cancellation
        // can also end with escrow status 3.
        assert!(
            order.completed_sale_recorded,
            E_ORDER_NOT_COMPLETED
        );

        assert!(
            !order.stock_restored,
            E_ORDER_NOT_COMPLETED
        );

        // Defense in depth: escrow itself must also be completed.
        assert!(
            escrow::status(escrow_object) == 3,
            E_ORDER_NOT_COMPLETED
        );

        // One review per order.
        assert!(
            !order.reviewed,
            E_ORDER_ALREADY_REVIEWED
        );

        let review = ProductReview {
            id: object::new(ctx),

            order: object::id(order),
            escrow: object::id(escrow_object),
            product: object::id(product),

            merchant: order.seller,
            reviewer,

            rating,
            comment,

            created_at: clock::timestamp_ms(clock),
        };

        reputation.total_reviews =
            reputation.total_reviews + 1;

        reputation.total_rating =
            reputation.total_rating + (rating as u64);

        if (rating == 5) {
            reputation.five_star =
                reputation.five_star + 1;
        } else if (rating == 4) {
            reputation.four_star =
                reputation.four_star + 1;
        } else if (rating == 3) {
            reputation.three_star =
                reputation.three_star + 1;
        } else if (rating == 2) {
            reputation.two_star =
                reputation.two_star + 1;
        } else {
            reputation.one_star =
                reputation.one_star + 1;
        };

        order.reviewed = true;

        let review_id = object::id(&review);

        event::emit(ReviewCreated {
            review_id,
            order_id: object::id(order),
            escrow_id: object::id(escrow_object),
            product_id: object::id(product),
            merchant: order.seller,
            reviewer,
            rating,
        });

        transfer::share_object(review);
    }

    fun checked_mul(a: u64, b: u64): u64 {
        if (a == 0 || b == 0) {
            return 0
        };

        assert!(
            a <= 18446744073709551615 / b,
            E_MATH_OVERFLOW
        );

        a * b
    }

    fun checked_add_u64(a: u64, b: u64): u64 {
        assert!(
            a <= 18446744073709551615 - b,
            E_MATH_OVERFLOW
        );

        a + b
    }

    fun checked_add_u32(a: u32, b: u32): u32 {
        assert!(
            a <= 4294967295 - b,
            E_MATH_OVERFLOW
        );

        a + b
    }

    fun validate_deposit_override(value: &option::Option<u16>) {
        if (option::is_some(value)) {
            assert!((*option::borrow(value) as u64) <= MAX_BPS, E_INVALID_DEPOSIT_PERCENT);
        };
    }

    fun effective_deposit_bps(product: &Product, merchant: &MerchantProfile): u64 {
        if (option::is_some(&product.seller_deposit_bps_override)) {
            *option::borrow(&product.seller_deposit_bps_override) as u64
        } else {
            merchant.seller_deposit_bps as u64
        }
    }

    // ============================================================
    // Read Helpers
    // ============================================================

    public fun merchant_authority(
        merchant: &MerchantProfile,
    ): address {
        merchant.authority
    }

    public fun merchant_active(
        merchant: &MerchantProfile,
    ): bool {
        merchant.active
    }

    public fun merchant_total_sold(
        merchant: &MerchantProfile,
    ): u32 {
        merchant.total_sold
    }

    public fun product_object_id(
        product: &Product,
    ): ID {
        object::id(product)
    }

    public fun product_merchant(
        product: &Product,
    ): address {
        product.merchant
    }

    public fun product_id(
        product: &Product,
    ): u64 {
        product.product_id
    }

    public fun product_price(
        product: &Product,
    ): u64 {
        product.price
    }

    public fun product_stock(
        product: &Product,
    ): u32 {
        product.stock
    }

    public fun product_sold(
        product: &Product,
    ): u32 {
        product.sold
    }

    public fun product_active(
        product: &Product,
    ): bool {
        product.active
    }

    public fun product_deleted(
        product: &Product,
    ): bool {
        product.deleted
    }

    public fun order_buyer(order: &OrderRecord): address {
        order.buyer
    }

    public fun order_seller(order: &OrderRecord): address {
        order.seller
    }

    public fun order_quantity(order: &OrderRecord): u32 {
        order.quantity
    }

    public fun order_unit_price(order: &OrderRecord): u64 {
        order.unit_price
    }

    public fun order_total_price(order: &OrderRecord): u64 {
        order.total_price
    }

    public fun order_security_deposit(order: &OrderRecord): u64 {
        order.security_deposit
    }

    public fun order_completed_sale_recorded(
        order: &OrderRecord,
    ): bool {
        order.completed_sale_recorded
    }

    public fun order_stock_restored(
        order: &OrderRecord,
    ): bool {
        order.stock_restored
    }

    public fun order_reviewed(
        order: &OrderRecord,
    ): bool {
        order.reviewed
    }

    public fun reputation_merchant(
        reputation: &MerchantReputation,
    ): address {
        reputation.merchant
    }

    public fun reputation_total_reviews(
        reputation: &MerchantReputation,
    ): u64 {
        reputation.total_reviews
    }

    public fun reputation_total_rating(
        reputation: &MerchantReputation,
    ): u64 {
        reputation.total_rating
    }

    public fun reputation_five_star(
        reputation: &MerchantReputation,
    ): u64 {
        reputation.five_star
    }

    public fun reputation_four_star(
        reputation: &MerchantReputation,
    ): u64 {
        reputation.four_star
    }

    public fun reputation_three_star(
        reputation: &MerchantReputation,
    ): u64 {
        reputation.three_star
    }

    public fun reputation_two_star(
        reputation: &MerchantReputation,
    ): u64 {
        reputation.two_star
    }

    public fun reputation_one_star(
        reputation: &MerchantReputation,
    ): u64 {
        reputation.one_star
    }

        public fun message_product(
        message: &ChatMessage,
    ): ID {
        message.product
    }

    public fun message_buyer(
        message: &ChatMessage,
    ): address {
        message.buyer
    }

    public fun message_seller(
        message: &ChatMessage,
    ): address {
        message.seller
    }

    public fun message_sender(
        message: &ChatMessage,
    ): address {
        message.sender
    }

    public fun message_recipient(
        message: &ChatMessage,
    ): address {
        message.recipient
    }

    public fun message_created_at(
        message: &ChatMessage,
    ): u64 {
        message.created_at
    }

    // Solana-compatible escrow-scoped messaging.
    public fun send_message(
        product: &Product,
        escrow_object: &Escrow,
        message: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let buyer = escrow::party_a_address(escrow_object);
        let seller = escrow::party_b_address(escrow_object);
        assert!(contains_solzaar_marker(escrow::note(escrow_object)), E_NOT_SOLZAAR_ESCROW);
        assert!(product.merchant == seller && buyer != seller, E_INVALID_ESCROW_PARTIES);
        assert!(sender == buyer || sender == seller, E_UNAUTHORIZED);
        assert!(message.length() > 0, E_EMPTY_MESSAGE);
        assert!(message.length() <= MAX_MESSAGE_LENGTH, E_MESSAGE_TOO_LONG);
        let recipient = if (sender == buyer) { seller } else { buyer };
        let chat_message = ChatMessage {
            id: object::new(ctx),
            product: object::id(product),
            buyer,
            seller,
            sender,
            recipient,
            message,
            created_at: clock::timestamp_ms(clock),
        };
        let message_id = object::id(&chat_message);
        event::emit(MessageSent {
            message_id,
            product: object::id(product),
            buyer,
            seller,
            sender,
            recipient,
            created_at: clock::timestamp_ms(clock),
        });
        transfer::share_object(chat_message);
    }

    public fun send_product_message(
        product: &Product,
        buyer: address,
        message: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let seller = product.merchant;

        // Product must still exist as a valid listing.
        assert!(
            !product.deleted,
            E_PRODUCT_DELETED
        );

        // Buyer and seller cannot be the same wallet.
        assert!(
            buyer != seller,
            E_INVALID_ESCROW_PARTIES
        );

        // Only the specified buyer or product seller
        // may participate in this conversation.
        assert!(
            sender == buyer || sender == seller,
            E_UNAUTHORIZED
        );

        // Message cannot be empty.
        assert!(
            message.length() > 0,
            E_EMPTY_MESSAGE
        );

        // Limit message size.
        assert!(
            message.length() <= MAX_MESSAGE_LENGTH,
            E_MESSAGE_TOO_LONG
        );

        // Recipient is derived by the contract.
        let recipient =
            if (sender == buyer) {
                seller
            } else {
                buyer
            };

        let chat_message = ChatMessage {
            id: object::new(ctx),

            product: object::id(product),
            buyer,
            seller,

            sender,
            recipient,

            message,
            created_at: clock::timestamp_ms(clock),
        };

        let message_id =
            object::uid_to_inner(&chat_message.id);

        event::emit(MessageSent {
            message_id,
            product: object::id(product),

            buyer,
            seller,

            sender,
            recipient,

            created_at: clock::timestamp_ms(clock),
        });

        transfer::share_object(chat_message);
    }

        // ============================================================
    // Create Buyer-Funded Purchase Offer
    // ============================================================

    public fun create_purchase_offer(
        merchant: &MerchantProfile,
        product: &Product,
        escrow_object: &Escrow,
        unit_price: u64,
        quantity: u32,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let buyer = tx_context::sender(ctx);
        let seller = product.merchant;
        let now = clock::timestamp_ms(clock);

        // --------------------------------------------------------
        // Merchant / Product validation
        // --------------------------------------------------------

        assert!(
            merchant.authority == seller,
            E_UNAUTHORIZED
        );

        assert!(
            merchant.active,
            E_MERCHANT_INACTIVE
        );

        assert!(
            product.active,
            E_PRODUCT_DELETED
        );

        assert!(
            !product.deleted,
            E_PRODUCT_DELETED
        );

        // Buyer cannot make an offer to their own product.
        assert!(
            buyer != seller,
            E_INVALID_ESCROW_PARTIES
        );

        // --------------------------------------------------------
        // Offer validation
        // --------------------------------------------------------

        assert!(
            unit_price > 0,
            E_INVALID_SPECIAL_PRICE
        );

        assert!(
            quantity > 0,
            E_INVALID_QUANTITY
        );

        assert!(
            product.stock >= quantity,
            E_INSUFFICIENT_STOCK
        );

        assert!(unit_price < product.price, E_INVALID_ORDER_AMOUNT);

        // No automatic expiration; status and authorization checks remain.

        // --------------------------------------------------------
        // Calculate negotiated amount
        // --------------------------------------------------------

        let quantity_u64 = quantity as u64;

        let total_price =
            checked_mul(
                unit_price,
                quantity_u64
            );

        let deposit_numerator =
            checked_mul(
                total_price,
                effective_deposit_bps(product, merchant)
            );

        let mut security_deposit =
            deposit_numerator / 10_000;

        // Same minimum deposit behavior as normal orders.
        if (security_deposit == 0) {
            security_deposit = 1;
        };

        let buyer_deposit =
            checked_add_u64(
                total_price,
                security_deposit
            );

        // --------------------------------------------------------
        // Verify exact buyer-funded escrow
        // --------------------------------------------------------

        // Seller must not have deposited yet.
        assert!(
            escrow::status(escrow_object) == 0,
            E_INVALID_ORDER_STATUS
        );

        // Buyer must be the escrow creator.
        assert!(
            escrow::creator(escrow_object) == buyer,
            E_INVALID_ESCROW_PARTIES
        );

        // Must be a Solzaar-created escrow.
        assert!(
            contains_solzaar_marker(
                escrow::note(escrow_object)
            ),
            E_NOT_SOLZAAR_ESCROW
        );

        let party_a =
            escrow::party_a_address(escrow_object);

        let party_b =
            escrow::party_b_address(escrow_object);

        assert!(
            party_a == buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            party_b == seller,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            party_a != party_b,
            E_INVALID_ESCROW_PARTIES
        );

        // Exact negotiated sale amount.
        assert!(
            escrow::reference_amount(escrow_object)
                == total_price,
            E_INVALID_ORDER_AMOUNT
        );

        // Exact amount buyer was required to deposit.
        assert!(
            escrow::required_deposit_a(escrow_object)
                == buyer_deposit,
            E_INVALID_BUYER_DEPOSIT
        );

        // Buyer funds must already be locked.
        assert!(
            escrow::deposited_a(escrow_object)
                == buyer_deposit,
            E_BUYER_DEPOSIT_INCOMPLETE
        );

        // Seller's required future security deposit.
        assert!(
            escrow::required_deposit_b(escrow_object)
                == security_deposit,
            E_INVALID_SELLER_DEPOSIT
        );

        // --------------------------------------------------------
        // Create PurchaseOffer
        // --------------------------------------------------------

        let offer = PurchaseOffer {
            id: object::new(ctx),

            product: object::id(product),
            escrow: object::id(escrow_object),

            buyer,
            seller,

            unit_price,
            quantity,
            total_price,
            security_deposit,
            buyer_deposit,

            active: true,
            accepted: false,
            rejected: false,
            withdrawn: false,

            created_at: now,
        };

        let offer_id =
            object::uid_to_inner(&offer.id);

        event::emit(PurchaseOfferCreated {
            offer_id,

            product:
                object::id(product),

            escrow:
                object::id(escrow_object),

            buyer,
            seller,

            unit_price,
            quantity,
            total_price,
            buyer_deposit,
        });


        transfer::share_object(offer);
    }


    // ============================================================
    // Accept Buyer-Funded Purchase Offer
    // ============================================================

    public fun accept_purchase_offer(
        registry: &mut MerchantRegistry,
        merchant: &MerchantProfile,
        product: &mut Product,
        offer: &mut PurchaseOffer,
        escrow_object: &Escrow,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let seller = tx_context::sender(ctx);
        let now = clock::timestamp_ms(clock);

        // --------------------------------------------------------
        // Seller / merchant validation
        // --------------------------------------------------------

        assert!(
            seller == offer.seller,
            E_UNAUTHORIZED
        );

        assert!(
            merchant.authority == seller,
            E_UNAUTHORIZED
        );

        assert!(
            merchant.active,
            E_MERCHANT_INACTIVE
        );

        // --------------------------------------------------------
        // Offer validation
        // --------------------------------------------------------

        assert!(
            offer.active,
            E_PURCHASE_OFFER_INACTIVE
        );

        assert!(
            !offer.accepted &&
            !offer.rejected &&
            !offer.withdrawn,
            E_PURCHASE_OFFER_INACTIVE
        );

        // No automatic expiration; status and authorization checks remain.

        // --------------------------------------------------------
        // Escrow validation
        // --------------------------------------------------------

        assert!(
            escrow::status(escrow_object) == 1,
            E_INVALID_ORDER_STATUS
        );

        assert!(
            escrow::deposited_a(escrow_object) == offer.buyer_deposit,
            E_BUYER_DEPOSIT_INCOMPLETE
        );

        assert!(
            object::id(escrow_object) == offer.escrow,
            E_INVALID_ORDER_STATUS
        );

        // --------------------------------------------------------
        // Product validation
        // --------------------------------------------------------

        assert!(
            object::id(product) == offer.product,
            E_PURCHASE_OFFER_PRODUCT_MISMATCH
        );

        assert!(
            product.merchant == seller,
            E_UNAUTHORIZED
        );

        assert!(
            product.active && !product.deleted,
            E_PRODUCT_DELETED
        );

        assert!(
            offer.quantity > 0,
            E_INVALID_QUANTITY
        );

        assert!(
            product.stock >= offer.quantity,
            E_INSUFFICIENT_STOCK
        );

        // --------------------------------------------------------
        // Verify offer amounts
        // --------------------------------------------------------

        assert!(
            offer.unit_price > 0,
            E_INVALID_SPECIAL_PRICE
        );

        let expected_total = checked_mul(
            offer.unit_price,
            offer.quantity as u64
        );

        assert!(
            expected_total == offer.total_price,
            E_INVALID_ORDER_AMOUNT
        );

        let expected_buyer_deposit = checked_add_u64(
            offer.total_price,
            offer.security_deposit
        );

        assert!(
            expected_buyer_deposit == offer.buyer_deposit,
            E_INVALID_BUYER_DEPOSIT
        );

        // --------------------------------------------------------
        // Escrow validation
        // --------------------------------------------------------

        assert!(
            object::id(escrow_object) == offer.escrow,
            E_PURCHASE_OFFER_ESCROW_MISMATCH
        );

        assert!(
            escrow::status(escrow_object) == 1,
            E_INVALID_ORDER_STATUS
        );

        assert!(
            escrow::creator(escrow_object) == offer.buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            contains_solzaar_marker(
                escrow::note(escrow_object)
            ),
            E_NOT_SOLZAAR_ESCROW
        );

        assert!(
            escrow::party_a_address(escrow_object)
                == offer.buyer,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            escrow::party_b_address(escrow_object)
                == seller,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            offer.buyer != seller,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            escrow::reference_amount(escrow_object)
                == offer.total_price,
            E_INVALID_ORDER_AMOUNT
        );

        assert!(
            escrow::required_deposit_a(escrow_object)
                == offer.buyer_deposit,
            E_INVALID_BUYER_DEPOSIT
        );

        assert!(
            escrow::deposited_a(escrow_object)
                == offer.buyer_deposit,
            E_BUYER_DEPOSIT_INCOMPLETE
        );

        assert!(
            escrow::required_deposit_b(escrow_object)
                == offer.security_deposit,
            E_INVALID_SELLER_DEPOSIT
        );

        assert!(
            escrow::deposited_b(escrow_object) == offer.security_deposit,
            E_INVALID_SELLER_DEPOSIT
        );

        // --------------------------------------------------------
        // Reserve product stock
        // --------------------------------------------------------

        bind_escrow(registry, offer.escrow);

        product.stock = product.stock - offer.quantity;
        product.updated_at = now;

        // --------------------------------------------------------
        // Create OrderRecord
        // --------------------------------------------------------

        let order = OrderRecord {
            id: object::new(ctx),

            escrow: offer.escrow,
            product: offer.product,

            buyer: offer.buyer,
            seller,

            quantity: offer.quantity,
            unit_price: offer.unit_price,
            total_price: offer.total_price,
            security_deposit: offer.security_deposit,

            completed_sale_recorded: false,
            stock_restored: false,
            reviewed: false,

            created_at: now,
        };

        let order_id = object::uid_to_inner(&order.id);

        // --------------------------------------------------------
        // Mark offer accepted
        // --------------------------------------------------------

        offer.active = false;
        offer.accepted = true;

        // --------------------------------------------------------
        // Emit events
        // --------------------------------------------------------

        event::emit(PurchaseOfferAccepted {
            offer_id: object::id(offer),
            product: offer.product,
            escrow: offer.escrow,
            buyer: offer.buyer,
            seller,
        });

        event::emit(OrderCreated {
            order_id,
            escrow_id: offer.escrow,
            product_id: offer.product,
            buyer: offer.buyer,
            seller,
            quantity: offer.quantity,
            total_price: offer.total_price,
        });

        transfer::share_object(order);
    }

    // ============================================================
    // Reject Buyer-Funded Purchase Offer
    // ============================================================

    public fun reject_purchase_offer(
        offer: &mut PurchaseOffer,
        ctx: &mut TxContext,
    ) {
        let seller = tx_context::sender(ctx);

        assert!(
            seller == offer.seller,
            E_UNAUTHORIZED
        );

        assert!(
            offer.active &&
            !offer.accepted &&
            !offer.rejected &&
            !offer.withdrawn,
            E_PURCHASE_OFFER_INACTIVE
        );

        offer.active = false;
        offer.rejected = true;

        event::emit(PurchaseOfferRejected {
            offer_id: object::id(offer),
            product: offer.product,
            escrow: offer.escrow,
            buyer: offer.buyer,
            seller: offer.seller,
        });
    }
    
    // ============================================================
    // Withdraw Pending Purchase Offer
    // ============================================================

    public fun withdraw_purchase_offer(
        offer: &mut PurchaseOffer,
        escrow_object: &mut Escrow,
        ctx: &mut TxContext,
    ) {
        let buyer = tx_context::sender(ctx);

        assert!(
            buyer == offer.buyer,
            E_UNAUTHORIZED
        );

        assert!(
            !offer.accepted &&
            !offer.withdrawn &&
            (offer.active || offer.rejected),
            E_PURCHASE_OFFER_INACTIVE
        );

        assert!(object::id(escrow_object) == offer.escrow, E_PURCHASE_OFFER_ESCROW_MISMATCH);
        assert!(escrow::status(escrow_object) == 0, E_INVALID_ORDER_STATUS);
        assert!(escrow::creator(escrow_object) == buyer, E_INVALID_ESCROW_PARTIES);
        assert!(escrow::party_a_address(escrow_object) == buyer, E_INVALID_ESCROW_PARTIES);
        assert!(escrow::party_b_address(escrow_object) == offer.seller, E_INVALID_ESCROW_PARTIES);
        assert!(escrow::deposited_a(escrow_object) == offer.buyer_deposit, E_BUYER_DEPOSIT_INCOMPLETE);
        assert!(escrow::deposited_b(escrow_object) == 0, E_INVALID_SELLER_DEPOSIT);
        escrow::withdraw_before_complete(escrow_object, ctx);
        assert!(escrow::status(escrow_object) == 4, E_INVALID_ORDER_STATUS);

        offer.active = false;
        offer.withdrawn = true;

        event::emit(PurchaseOfferWithdrawn {
            offer_id: object::id(offer),
            product: offer.product,
            escrow: offer.escrow,
            buyer: offer.buyer,
            seller: offer.seller,
        });
    }
     

    public fun create_special_price_offer(
        product: &Product,
        buyer: address,
        unit_price: u64,
        quantity: u32,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let seller = tx_context::sender(ctx);
        let now = clock::timestamp_ms(clock);

        // Seller only.
        assert!(
            seller == product.merchant,
            E_UNAUTHORIZED
        );

        assert!(
            product.active,
            E_PRODUCT_DELETED
        );

        assert!(
            !product.deleted,
            E_PRODUCT_DELETED
        );

        assert!(
            buyer != seller,
            E_INVALID_ESCROW_PARTIES
        );

        assert!(
            unit_price > 0,
            E_INVALID_SPECIAL_PRICE
        );

        assert!(
            quantity > 0,
            E_INVALID_QUANTITY
        );

        assert!(
            product.stock >= quantity,
            E_INSUFFICIENT_STOCK
        );

        // Offers do not expire automatically.
        // No automatic expiration; status and authorization checks remain.

        let offer = SpecialPriceOffer {
            id: object::new(ctx),

            product: object::id(product),
            seller,
            buyer,

            unit_price,
            quantity,

            active: true,
            used: false,

            created_at: now,
        };

        let offer_id =
            object::uid_to_inner(&offer.id);

        event::emit(SpecialPriceOffered {
            offer_id,
            product: object::id(product),

            seller,
            buyer,

            unit_price,
            quantity,
        });

        transfer::share_object(offer);
    }

    public fun cancel_special_price_offer(
        offer: &mut SpecialPriceOffer,
        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        // Only the seller who created the offer may cancel it.
        assert!(
            sender == offer.seller,
            E_UNAUTHORIZED
        );

        // Already cancelled or already consumed offers
        // cannot be cancelled again.
        assert!(
            offer.active,
            E_SPECIAL_OFFER_INACTIVE
        );

        assert!(
            !offer.used,
            E_SPECIAL_OFFER_INACTIVE
        );

        offer.active = false;

        event::emit(SpecialPriceOfferCancelled {
            offer_id: object::id(offer),
            product: offer.product,
            seller: offer.seller,
            buyer: offer.buyer,
        });
    }

    public fun special_offer_product(
        offer: &SpecialPriceOffer,
    ): ID {
        offer.product
    }

    public fun special_offer_seller(
        offer: &SpecialPriceOffer,
    ): address {
        offer.seller
    }

    public fun special_offer_buyer(
        offer: &SpecialPriceOffer,
    ): address {
        offer.buyer
    }

    public fun special_offer_unit_price(
        offer: &SpecialPriceOffer,
    ): u64 {
        offer.unit_price
    }

    public fun special_offer_quantity(
        offer: &SpecialPriceOffer,
    ): u32 {
        offer.quantity
    }

    public fun special_offer_active(
        offer: &SpecialPriceOffer,
    ): bool {
        offer.active
    }

    public fun special_offer_used(
        offer: &SpecialPriceOffer,
    ): bool {
        offer.used
    }

    public fun special_offer_created_at(
        offer: &SpecialPriceOffer,
    ): u64 {
        offer.created_at
    }

        public fun purchase_offer_unit_price(
        offer: &PurchaseOffer,
    ): u64 {
        offer.unit_price
    }

    public fun purchase_offer_total_price(
        offer: &PurchaseOffer,
    ): u64 {
        offer.total_price
    }

    public fun purchase_offer_buyer_deposit(
        offer: &PurchaseOffer,
    ): u64 {
        offer.buyer_deposit
    }

    public fun purchase_offer_active(
        offer: &PurchaseOffer,
    ): bool {
        offer.active
    }

    fun bind_escrow(
        registry: &mut MerchantRegistry,
        escrow_id: ID,
    ) {
        assert!(
            !dynamic_field::exists(&registry.id, escrow_id),
            E_ESCROW_ALREADY_BOUND
        );

        dynamic_field::add(
            &mut registry.id,
            escrow_id,
            true,
        );
    }
}