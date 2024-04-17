module defraud::budget_tracking {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    // Errors
    const ENotEnough: u64 = 0;
    const ERetailerPending: u64 = 1;
    const EUndeclaredClaim: u64 = 2;
    const ENotValidatedByBank: u64 = 3;
    const ENotOwner: u64 = 4;

    // Struct definitions
    struct BudgetManager has key {
        id:UID,
        expense: ID
    }

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

   // === Public-Mutative Functions ===

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
    public fun record_expense(tr_id: u64, claim_id:u64, amount: u64, ctx: &mut TxContext) : BudgetManager {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        // share the object 
        transfer::share_object(ExpenseTracking {
            id: id_,
            owner_address: tx_context::sender(ctx),
            bank_transac_id: tr_id,
            police_claim_id: claim_id,
            amount: amount,
            refund: balance::zero(),
            retailer_is_pending: false,
            bank_validation: false
        });
        let cap = BudgetManager{
            id: object::new(ctx),
            expense: inner_
        };
        cap
    }

    public entry fun edit_claim_id(cap: &BudgetManager, self: &mut ExpenseTracking, claim_id: u64) {
        assert!(cap.expense == object::id(self), ENotOwner);
        assert!(self.retailer_is_pending, ERetailerPending);
        self.police_claim_id = claim_id;
    }

    public entry fun deposit(self: &mut ExpenseTracking, coin: Coin<SUI>) {
        assert!(coin::value(&coin) == self.amount, ENotEnough);
        assert!(self.police_claim_id == 0, EUndeclaredClaim);

        let balance_ = coin::into_balance(coin);
        balance::join(&mut self.refund, balance_);
    }

    public entry fun validate_with_bank(cap: &BudgetManager, self: &mut ExpenseTracking) {
        assert!(cap.expense == object::id(self), ENotOwner);
        self.bank_validation = true;
    }

    public entry fun claim_from_retailer(cap: BudgetManager, self: &mut ExpenseTracking, address_: address, ctx: &mut TxContext) {
        assert!(cap.expense == object::id(self), ENotOwner);
        assert!(self.police_claim_id == 0, EUndeclaredClaim);

        // Transfer the balance
        let amount = balance::value(&self.refund);
        let refund = coin::take(&mut self.refund, amount, ctx);
        transfer::public_transfer(refund, tx_context::sender(ctx));

        // Transfer the ownership
        self.owner_address = address_;
        transfer::transfer(cap, address_);
    }

    public entry fun claim_from_bank(cap: &BudgetManager, self: &mut ExpenseTracking, ctx: &mut TxContext) {
        assert!(cap.expense == object::id(self), ENotOwner);
        assert!(self.retailer_is_pending, ERetailerPending);
        assert!(self.bank_validation == false, ENotValidatedByBank);

        // Transfer the balance
        let amount = balance::value(&self.refund);
        let refund = coin::take(&mut self.refund, amount, ctx);
        transfer::public_transfer(refund, tx_context::sender(ctx));
    }

    public fun set_retailer_pending(cap: &BudgetManager, self: &mut ExpenseTracking, ctx: &mut TxContext) {
        assert!(cap.expense == object::id(self), ENotOwner);
        self.retailer_is_pending = true;
    }
}
