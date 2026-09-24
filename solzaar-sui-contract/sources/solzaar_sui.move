module solzaar_sui::marketplace {

    use std::string::String;
    use std::vector;

    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

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

        transfer::share_object(merchant);
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

        product.title = title;
        product.description_uri =
            description_uri;
        product.image_uris = image_uris;
        product.category = category;
        product.price = price;
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

    public fun create_order_record(
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
            product.price * quantity_u64;

        assert!(
            quantity_u64 == 0 ||
                total_price / quantity_u64 == product.price,
            E_MATH_OVERFLOW
        );

        let deposit_numerator =
            total_price * (merchant.seller_deposit_bps as u64);

        assert!(
            total_price == 0 ||
                deposit_numerator / total_price ==
                    (merchant.seller_deposit_bps as u64),
            E_MATH_OVERFLOW
        );

        let mut security_deposit =
            deposit_numerator / 10_000;

        // Same behavior as Solana contract:
        // minimum seller security deposit is 1 MIST.
        if (security_deposit == 0) {
            security_deposit = 1;
        };

        let expected_buyer_deposit =
            total_price + security_deposit;

        assert!(
            expected_buyer_deposit >= total_price,
            E_MATH_OVERFLOW
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
            product.sold + order.quantity;

        merchant.total_sold =
            merchant.total_sold + order.quantity;

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
            product.stock + order.quantity;

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
            product.stock + order.quantity;

        order.stock_restored = true;
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
}