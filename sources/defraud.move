module budget_tracking::budget_tracking {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self as Coin, Coin};
    use sui::object::{Self as Obj, UID};
    use sui::balance::{Self as Bal, Balance};
    use sui::tx_context::{Self as TxCtx, TxContext};
    use sui::address::{Self as Addr, Address};

    // Errors
    const ENotEnough: u64 = 0;
    const ERetailerPending: u64 = 1;
    const EUndeclaredClaim: u64 = 2;
    const ENotValidatedByBank: u64 = 3;
    const ENotOwner: u64 = 4;

    // Struct definitions
    struct BudgetManager has key { id: UID }

    struct ExpenseTracking has key, store {
        id: UID,                            // Transaction object ID
        owner_address: Address,             // Owner address
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
            id: Obj::new(ctx),
        }, TxCtx::sender(ctx))
    }

    // Accessors
    public entry fun bank_transac_id(_: &BudgetManager, expense: &ExpenseTracking): u64 {
        expense.bank_transac_id
    }

    public entry fun amount(expense: &ExpenseTracking, ctx: &mut TxContext) -> u64 {
        assert!(expense.owner_address != TxCtx::sender(ctx), ENotOwner);
        expense.amount
    }

    public entry fun claim_id(expense: &ExpenseTracking): u64 {
        expense.police_claim_id
    }

    public entry fun is_refunded(expense: &ExpenseTracking): u64 {
        Bal::value(&expense.refund)
    }

    public entry fun bank_has_validated(expense: &ExpenseTracking): bool {
        expense.bank_validation
    }

    // Public - Entry functions
    public entry fun record_expense(tr_id: u64, claim_id: u64, amount: u64, ctx: &mut TxContext) {
        transfer::share_object(ExpenseTracking {
            owner_address: TxCtx::sender(ctx),
            id: Obj::new(ctx),
            bank_transac_id: tr_id,
            police_claim_id: claim_id,
            amount: amount,
            refund: Bal::zero(),
            retailer_is_pending: false,
            bank_validation: false
        });
    }

    public entry fun create_budget_manager(_: &BudgetManager, bank_address: Address, ctx: &mut TxContext) {
        transfer::transfer(BudgetManager {
            id: Obj::new(ctx), // Initialize with a placeholder value, actual ID will be assigned during execution
        }, bank_address);
    }

    public entry fun edit_claim_id(expense: &mut ExpenseTracking, claim_id: u64, ctx: &mut TxContext) {
        assert!(expense.owner_address != TxCtx::sender(ctx), ENotOwner);
        assert!(expense.retailer_is_pending, ERetailerPending);
        expense.police_claim_id = claim_id;
    }

    public entry fun refund(expense: &mut ExpenseTracking, funds: &mut Coin<SUI>, ctx: &mut TxContext) {
        assert!(Coin::value(funds) >= expense.amount, ENotEnough);
        assert!(expense.police_claim_id == 0, EUndeclaredClaim);

        let coin_balance = Coin::balance_mut(funds);
        let paid = Bal::split(coin_balance, expense.amount);

        Bal::join(&mut expense.refund, paid);
    }

    public entry fun validate_with_bank(_: &BudgetManager, expense: &mut ExpenseTracking) {
        expense.bank_validation = true;
    }

    public entry fun claim_from_retailer(expense: &mut ExpenseTracking, retailer_address: Address, ctx: &mut TxContext) {
        assert!(expense.owner_address != TxCtx::sender(ctx), ENotOwner);
        assert!(expense.police_claim_id == 0, EUndeclaredClaim);

        // Transfer the balance
        let amount = Bal::value(&expense.refund);
        let refund = Coin::take(&mut expense.refund, amount, ctx);
        transfer::public_transfer(refund, retailer_address);

        // Transfer the ownership
        expense.owner_address = retailer_address;
    }

    public entry fun claim_from_bank(expense: &mut ExpenseTracking, ctx: &mut TxContext) {
        assert!(expense.owner_address != TxCtx::sender(ctx), ENotOwner);
        assert!(expense.retailer_is_pending, ERetailerPending);
        assert!(!expense.bank_validation, ENotValidatedByBank);

        // Transfer the balance
        let amount = Bal::value(&expense.refund);
        let refund = Coin::take(&mut expense.refund, amount, ctx);
        transfer::public_transfer(refund, TxCtx::sender(ctx));
    }

    // New functionality: Mark expense as pending refund by retailer
    public entry fun mark_retailer_pending(expense: &mut ExpenseTracking, ctx: &mut TxContext) {
        assert!(expense.owner_address == TxCtx::sender(ctx), ENotOwner);
        expense.retailer_is_pending = true;
    }

    // New functionality: Check if expense is pending refund by retailer
    public entry fun is_retailer_pending(expense: &ExpenseTracking): bool {
        expense.retailer_is_pending
    }

    // New functionality: Check if expense is claimed by police
    public entry fun is_police_claimed(expense: &ExpenseTracking): bool {
        expense.police_claim_id != 0
    }

    // New functionality: Set bank transaction ID
    public entry fun set_bank_transac_id(expense: &mut ExpenseTracking, tr_id: u64, ctx: &mut TxContext) {
        assert!(expense.owner_address == TxCtx::sender(ctx), ENotOwner);
        expense.bank_transac_id = tr_id;
    }
}
