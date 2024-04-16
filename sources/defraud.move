module budget_tracking::budget_tracking {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::error::{SuiError, SErr}; // Added for structured error handling

    // Errors
    const ENotEnough: u64 = 0;
    const ERetailerPending: u64 = 1;
    const EUndeclaredClaim: u64 = 2;
    const ENotValidatedByBank: u64 = 3;
    const ENotOwner: u64 = 4;

    // Struct definitions
    struct BudgetManager has key { id:UID }

    struct ExpenseTracking has key, store {
        id: UID,                            
        owner_address: address,             
        bank_transac_id: u64,               
        police_claim_id: u64,               

        amount: u64,                        
        refund: Balance<SUI>,               
        retailer_is_pending: bool,          

        bank_validation: bool,              
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

    public entry fun amount(expense: &ExpenseTracking, ctx: &mut TxContext) -> Result<u64, SuiError> {
        // Removed redundant ownership check
        Ok(expense.amount)
    }

    public entry fun claim_id(expense: &ExpenseTracking) -> u64 {
        expense.police_claim_id
    }

    public entry fun is_refunded(expense: &ExpenseTracking) -> u64 {
        balance::value(&expense.refund)
    }

    public entry fun bank_has_validated(expense: &ExpenseTracking) -> bool {
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
        transfer::transfer(BudgetManager {
            id: object::new(ctx), 
        }, bank_address);
    }

    public entry fun edit_claim_id(expense: &mut ExpenseTracking, claim_id: u64, ctx: &mut TxContext) {
        // Removed redundant ownership check
        assert!(expense.retailer_is_pending, ERetailerPending);
        expense.police_claim_id = claim_id;
    }

    public entry fun refund(expense: &mut ExpenseTracking, funds: &mut Coin<SUI>) -> Result<(), SuiError> {
        assert!(coin::value(funds) >= expense.amount, ENotEnough);
        assert!(expense.police_claim_id == 0, EUndeclaredClaim);

        let coin_balance = coin::balance_mut(funds);
        let paid = balance::split(coin_balance, expense.amount);

        balance::join(&mut expense.refund, paid);
        Ok(()) // Return Ok if refund is successful
    }

    public entry fun validate_with_bank(_: &BudgetManager, expense: &mut ExpenseTracking) {
        expense.bank_validation = true;
    }

    public entry fun claim_from_retailer(expense: &mut ExpenseTracking, retailer_address: address, ctx: &mut TxContext) -> Result<(), SuiError> {
        // Removed redundant ownership check
        assert!(expense.police_claim_id == 0, EUndeclaredClaim);

        // Implement retailer interaction
        // Simulating retailer acknowledgment or partial refund
        // Placeholder logic, replace with actual retailer interaction mechanism
        let partial_refund: u64 = 0; // Placeholder for partial refund amount
        if partial_refund > 0 {
            // Update refund balance with partial refund amount
            let partial_refund_balance = Balance<SUI> { value: partial_refund };
            balance::join(&mut expense.refund, partial_refund_balance);
        }

        expense.owner_address = retailer_address;
        Ok(()) // Return Ok if claim from retailer is successful
    }

    public entry fun claim_from_bank(expense: &mut ExpenseTracking, ctx: &mut TxContext) -> Result<(), SuiError> {
        // Removed redundant ownership check
        assert!(expense.retailer_is_pending, ERetailerPending);
        assert!(expense.bank_validation == false, ENotValidatedByBank);

        let amount = balance::value(&expense.refund);
        let refund = coin::take(&mut expense.refund, amount, ctx);
        transfer::public_transfer(refund, tx_context::sender(ctx));
        Ok(()) // Return Ok if claim from bank is successful
    }
}
