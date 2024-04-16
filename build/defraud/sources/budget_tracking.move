module budget_tracking::budget_tracking {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    // Errors
    const ENotEnough: u64 = 0;
    const ERetailerPending: u64 = 1;
    const EUndeclaredClaim: u64 = 2;
    const ENotValidatedByBank: u64 = 3;
    const ENotOwner: u64 = 4;

    // Struct definitions
    struct BudgetManager has key { id:UID }

    struct ExpenseTracking has key, store {
        id: UID,                            // Transaction object ID
        owner_address: address,             // Owner address
        bank_transac_id: u64,               // Bank Transaction ID
        police_claim_id: u64,               // Police claim ID

        amount: u64,                        // Transaction amount
        refund: Balance<SUI>,               // SUI Balance
        retailer_is_pending: bool,          // True if the retailer has refunded the customer

        bank_validation: bool,              // True if the bank has validated the fraud
    }

    // Module initializer
    fun init(ctx: &mut TxContext) {
        transfer::transfer(BudgetManager {
            id: object::new(ctx),
        }, tx_context::sender(ctx))
    }

    // Accessors
    public entry fun bank_transac_id(_: &BudgetManager, expense: &ExpenseTracking): u64 {
        expense.bank_transac_id
    }

    public entry fun amount(expense: &ExpenseTracking, ctx: &mut TxContext): u64 {
        assert!(expense.owner_address != tx_context::sender(ctx), ENotOwner);
        expense.amount
    }

    public entry fun claim_id(expense: &ExpenseTracking): u64 {
        expense.police_claim_id
    }

    public entry fun is_refunded(expense: &ExpenseTracking): u64 {
        balance::value(&expense.refund)
    }

    public entry fun bank_has_validated(expense: &ExpenseTracking): bool {
        expense.bank_validation
    }

    // Public - Entry functions
    public entry fun record_expense(tr_id: u64, claim_id:u64, amount: u64, ctx: &mut TxContext) {
        transfer::share_object(ExpenseTracking {
            owner_address: tx_context::sender(ctx),
            id: object::new(ctx),
            bank_transac_id: tr_id,
            police_claim_id: claim_id,
            amount: amount,
            refund: balance::zero(),
            retailer_is_pending: false,
            bank_validation: false
        });
    }

    public entry fun create_budget_manager(_: &BudgetManager, bank_address: address, ctx: &mut TxContext) {
        // No need for ctx parameter as it's not used
        transfer::transfer(BudgetManager {
            id: object::new(ctx), // Initialize with a placeholder value, actual ID will be assigned during execution
        }, bank_address);
    }

    public entry fun edit_claim_id(expense: &mut ExpenseTracking, claim_id: u64, ctx: &mut TxContext) {
        assert!(expense.owner_address != tx_context::sender(ctx), ENotOwner);
        assert!(expense.retailer_is_pending, ERetailerPending);
        expense.police_claim_id = claim_id;
    }

    public entry fun refund(expense: &mut ExpenseTracking, funds: &mut Coin<SUI>) {
        assert!(coin::value(funds) >= expense.amount, ENotEnough);
        assert!(expense.police_claim_id == 0, EUndeclaredClaim);

        let coin_balance = coin::balance_mut(funds);
        let paid = balance::split(coin_balance, expense.amount);

        balance::join(&mut expense.refund, paid);
    }

    public entry fun validate_with_bank(_: &BudgetManager, expense: &mut ExpenseTracking) {
        expense.bank_validation = true;
    }

    public entry fun claim_from_retailer(expense: &mut ExpenseTracking, retailer_address: address, ctx: &mut TxContext) {
        assert!(expense.owner_address != tx_context::sender(ctx), ENotOwner);
        assert!(expense.police_claim_id == 0, EUndeclaredClaim);

        // Transfer the balance
        let amount = balance::value(&expense.refund);
        let refund = coin::take(&mut expense.refund, amount, ctx);
        transfer::public_transfer(refund, tx_context::sender(ctx));

        // Transfer the ownership
        expense.owner_address = retailer_address;
    }

    public entry fun claim_from_bank(expense: &mut ExpenseTracking, ctx: &mut TxContext) {
        assert!(expense.owner_address != tx_context::sender(ctx), ENotOwner);
        assert!(expense.retailer_is_pending, ERetailerPending);
        assert!(expense.bank_validation == false, ENotValidatedByBank);

        // Transfer the balance
        let amount = balance::value(&expense.refund);
        let refund = coin::take(&mut expense.refund, amount, ctx);
        transfer::public_transfer(refund, tx_context::sender(ctx));
    }
}
