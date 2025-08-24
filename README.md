# StandardsVote

A decentralized voting system smart contract for industry standards approval on the Stacks blockchain. This contract enables registered voters to propose and vote on industry standards with built-in governance mechanisms including quorum requirements, approval thresholds, and proposal staking.

## Features

- **Decentralized Governance**: Democratic voting system for industry standard proposals
- **Voter Registration**: Only registered voters can participate in voting
- **Proposal Staking**: Proposers must stake STX tokens to prevent spam proposals
- **Time-bound Voting**: Each proposal has a defined voting period (~1 day)
- **Quorum Requirements**: Minimum participation threshold (20% of registered voters)
- **Approval Threshold**: 60% approval rate required for standards to pass
- **Transparent Results**: All votes and results are publicly verifiable on-chain
- **Automatic Finalization**: Standards are automatically finalized after voting period ends

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity v2
- **Epoch**: 2.5
- **Minimum Proposal Stake**: 1 STX (1,000,000 microSTX)
- **Voting Duration**: 144 blocks (~1 day)
- **Approval Threshold**: 60%
- **Minimum Quorum**: 20%

## Installation

### Prerequisites

- [Node.js](https://nodejs.org/) (v16 or higher)
- [Clarinet CLI](https://docs.stacks.co/clarinet)
- [Stacks CLI](https://docs.stacks.co/stacks-cli)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd StandardsVote
```

2. Navigate to the contract directory:
```bash
cd StandardsVote_contract
```

3. Install dependencies:
```bash
npm install
```

4. Check contract syntax:
```bash
clarinet check
```

5. Run tests:
```bash
npm test
```

## Usage Examples

### Register a Voter (Contract Owner Only)

```clarity
(contract-call? .StandardsVote register-voter 'SP1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ)
```

### Propose a New Standard

```clarity
(contract-call? .StandardsVote propose-standard 
  "JSON API v2.0 Specification"
  "Updated JSON API specification with improved error handling and pagination support")
```

### Vote on a Standard

```clarity
;; Vote in favor (true) or against (false)
(contract-call? .StandardsVote vote-on-standard u0 true)
```

### Finalize Voting

```clarity
(contract-call? .StandardsVote finalize-standard u0)
```

### Query Standard Information

```clarity
;; Get standard details
(contract-call? .StandardsVote get-standard u0)

;; Check voting statistics
(contract-call? .StandardsVote get-voting-stats u0)

;; Check if voting is still active
(contract-call? .StandardsVote is-voting-active u0)
```

## Contract Functions

### Public Functions

#### `register-voter(voter: principal)`
- **Description**: Registers a new voter (contract owner only)
- **Parameters**: `voter` - Principal address to register
- **Returns**: `(ok true)` on success
- **Errors**: `u100` (owner only), `u101` (already registered)

#### `propose-standard(title: string-ascii, description: string-utf8)`
- **Description**: Creates a new standard proposal
- **Parameters**: 
  - `title` - Standard title (max 256 chars)
  - `description` - Detailed description (max 1024 chars)
- **Returns**: `(ok standard-id)` on success
- **Requirements**: Must be registered voter with sufficient STX balance
- **Stake**: 1 STX locked until finalization

#### `vote-on-standard(standard-id: uint, vote: bool)`
- **Description**: Cast a vote on an active standard
- **Parameters**:
  - `standard-id` - ID of the standard to vote on
  - `vote` - `true` for approval, `false` for rejection
- **Returns**: `(ok true)` on success
- **Requirements**: Must be registered voter, voting must be active, one vote per voter

#### `finalize-standard(standard-id: uint)`
- **Description**: Finalizes voting after the voting period ends
- **Parameters**: `standard-id` - ID of the standard to finalize
- **Returns**: `(ok true)` on success
- **Logic**: 
  - Requires quorum (≥20% participation)
  - Requires approval (≥60% yes votes)
  - Returns stake to proposer if passed

### Read-Only Functions

#### `get-standard(standard-id: uint)`
Returns complete standard information including votes and status.

#### `is-registered-voter(voter: principal)`
Checks if a principal is a registered voter.

#### `get-vote(standard-id: uint, voter: principal)`
Returns vote details for a specific voter on a standard.

#### `get-total-registered-voters()`
Returns the total number of registered voters.

#### `get-next-standard-id()`
Returns the next available standard ID.

#### `is-voting-active(standard-id: uint)`
Checks if voting is currently active for a standard.

#### `get-voting-stats(standard-id: uint)`
Returns detailed voting statistics including percentages.

## Deployment Guide

### Local Development (Clarinet)

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy contract:
```clarity
::deploy
```

3. Interact with functions:
```clarity
::get_contracts
(contract-call? .StandardsVote get-total-registered-voters)
```

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deployments generate --testnet
clarinet deployments apply -p testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deployments generate --mainnet
clarinet deployments apply -p mainnet
```

## Security Notes

### Governance Security

- **Centralized Registration**: Initial voter registration is controlled by contract owner
- **Proposal Staking**: 1 STX stake prevents spam proposals
- **One Vote Per User**: Each voter can only vote once per standard
- **Time-bounded Voting**: Prevents indefinite voting periods

### Economic Security

- **Stake Forfeiture**: Failed proposals result in lost stake
- **Minimum Quorum**: Prevents decisions by small minorities
- **Approval Threshold**: Requires majority consensus (60%)

### Technical Security

- **Input Validation**: All inputs are validated for correctness
- **State Consistency**: Vote counts are atomically updated
- **Access Controls**: Proper authorization checks throughout
- **No Reentrancy**: Contract follows secure Clarity patterns

### Potential Risks

1. **Centralized Voter Registration**: Contract owner has significant control
2. **Plutocratic Elements**: Staking requirement may exclude some participants
3. **Block Time Variability**: Voting duration based on block height
4. **No Vote Delegation**: Direct voting only, no proxy voting

## Testing

Run the test suite:
```bash
npm test                # Run all tests
npm run test:report     # Run with coverage and cost analysis
npm run test:watch      # Watch mode for development
```

Tests cover:
- Voter registration functionality
- Standard proposal creation
- Voting mechanics
- Finalization logic
- Edge cases and error conditions
- Gas cost analysis

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and add tests
4. Run the test suite
5. Submit a pull request

## License

This project is licensed under the ISC License.

## Version History

- **v1.0.0**: Initial implementation with core voting functionality
  - Voter registration system
  - Standard proposal and voting
  - Automatic finalization with quorum and approval checks
  - Comprehensive test coverage