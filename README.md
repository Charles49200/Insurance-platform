# Insurance Module

The Insurance module facilitates the creation and management of insurance policies within a decentralized system. This module allows for the creation of policies, addition of policy holders, premium payments, and the calculation of coverage and claims. By leveraging the Move smart contracts, the Insurance module ensures transparent, secure, and efficient handling of insurance operations.

## Struct Definitions

### INSURANCE

Represents the main insurance module.

- **INSURANCE**: Main struct with the `drop` ability.

### AdminCap

Defines administrative capabilities.

- **id**: Unique identifier for the admin capability.

### Policy

Represents an insurance policy.

- **id**: Unique identifier for the policy.
- **premiums_per_second**: Rate of premiums accumulated per second.
- **start_timestamp**: Timestamp marking the start of the policy.
- **last_update_timestamp**: Timestamp of the last update.
- **accrued_coverage_per_share**: Accrued coverage per share.
- **balance_cover_coin**: Balance of cover coins in the policy.
- **balance_premium_coin**: Balance of premium coins in the policy.
- **cover_coin_decimal_factor**: Decimal factor for cover coins.
- **owned_by**: Identifier of the owner of the policy.

### PolicyCap

Defines capabilities related to policy management.

- **id**: Unique identifier for the policy capability.
- **policy**: ID associated with the specific policy.

### Holder

Represents a policy holder.

- **id**: Unique identifier for the holder.
- **policy_id**: ID of the associated policy.
- **coverage_amount**: Amount of coverage held.
- **claim_debt**: Outstanding claim debt.

## Public - Entry Functions

### `init`

Initializes the insurance module.

- **Parameters**: 
  - `_wtn`: The insurance module instance.
  - `ctx`: Transaction context.

### `new_policy`

Creates a new insurance policy.

- **Parameters**:
  - `cover_coin_metadata`: Metadata of the cover coin.
  - `c`: Clock instance.
  - `premiums_per_second`: Premium rate per second.
  - `start_timestamp`: Start time of the policy.
  - `ctx`: Transaction context.
- **Returns**: A tuple containing the `Policy` and `PolicyCap`.

### `new_holder`

Creates a new holder for an existing policy.

- **Parameters**:
  - `policy`: The policy to which the holder will be added.
  - `ctx`: Transaction context.
- **Returns**: The created `Holder`.

### `pending_coverage`

Calculates the pending coverage for a holder.

- **Parameters**:
  - `policy`: The associated policy.
  - `holder`: The holder whose pending coverage is being calculated.
  - `c`: Clock instance.
- **Returns**: The pending coverage amount.

### `purchase_coverage`

Allows a holder to purchase coverage.

- **Parameters**:
  - `policy`: The policy to which coverage is being added.
  - `holder`: The holder purchasing coverage.
  - `cover_coin`: The coin used for coverage.
  - `c`: Clock instance.
  - `ctx`: Transaction context.
- **Returns**: A coin of premium type.

### `withdraw_coverage`

Allows a holder to withdraw coverage.

- **Parameters**:
  - `policy`: The policy from which coverage is being withdrawn.
  - `holder`: The holder withdrawing coverage.
  - `amount`: Amount to withdraw.
  - `c`: Clock instance.
  - `ctx`: Transaction context.
- **Returns**: A tuple containing coins of cover and premium types.

### `add_premiums`

Adds premiums to a policy.

- **Parameters**:
  - `policy`: The policy to which premiums are being added.
  - `c`: Clock instance.
  - `premium`: The premium coin.

## Private Functions

### `clock_timestamp_s`

Gets the current timestamp in seconds.

- **Parameters**:
  - `c`: Clock instance.
- **Returns**: Current timestamp in seconds.

### `calculate_pending_coverage`

Calculates the pending coverage for a holder.

- **Parameters**:
  - `holder`: The holder whose pending coverage is being calculated.
  - `cover_factor`: Decimal factor for cover coins.
  - `accrued_coverage_per_share`: Accrued coverage per share.
- **Returns**: Pending coverage amount.

### `update`

Updates the policy state.

- **Parameters**:
  - `policy`: The policy being updated.
  - `now`: Current timestamp.

### `calculate_accrued_coverage_per_share`

Calculates the accrued coverage per share.

- **Parameters**:
  - `premiums_per_second`: Premium rate per second.
  - `last_accrued_coverage_per_share`: Last accrued coverage per share.
  - `total_covered_token`: Total covered token value.
  - `total_premium_value`: Total premium value.
  - `cover_factor`: Decimal factor for cover coins.
  - `timestamp_delta`: Difference between current and last update timestamps.
- **Returns**: Updated accrued coverage per share.

### `calculate_claim_debt`

Calculates the claim debt for a holder.

- **Parameters**:
  - `coverage_amount`: Coverage amount.
  - `cover_factor`: Decimal factor for cover coins.
  - `accrued_coverage_per_share`: Accrued coverage per share.
- **Returns**: Calculated claim debt.

### `min`

Finds the minimum of two u256 values.

- **Parameters**:
  - `x`: First value.
  - `y`: Second value.
- **Returns**: The minimum value.

### `min_u64`

Finds the minimum of two u64 values.

- **Parameters**:
  - `x`: First value.
  - `y`: Second value.
- **Returns**: The minimum value.


### Build and Deploy

1. Clone the Insurance module repository and navigate to the project directory.
2. Compile the smart contract code using:
    sui move build
3. Deploy the compiled smart contract to your local SUI blockchain node using the SUI CLI or other deployment tools.
4. Note the contract address and other relevant identifiers for interacting with the deployed contract.

### Usage

#### Creating a New Policy

Call the `new_policy` function with the required parameters to create a new policy.

#### Adding a Holder

Use the `new_holder` function to add a holder to an existing policy.

#### Managing Coverage

- **Purchase Coverage**: Call the `purchase_coverage` function to allow a holder to purchase coverage.
- **Withdraw Coverage**: Use the `withdraw_coverage` function to withdraw coverage for a holder.

#### Adding Premiums

Call the `add_premiums` function to add premiums to a policy.

### Interacting with the Smart Contract

#### Using the SUI CLI

Utilize the SUI CLI to interact with the deployed smart contract, providing function arguments and transaction contexts as required. Monitor transaction outputs and blockchain events to track policy management, coverage, and premium payments.

## Conclusion

The Insurance module provides a comprehensive solution for decentralized insurance management. By leveraging blockchain technology and smart contracts, it ensures secure, transparent, and efficient handling of insurance policies, premium payments, and claims.