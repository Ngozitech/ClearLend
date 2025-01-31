# ClearLend: Decentralized P2P Lending Protocol

A decentralized peer-to-peer lending protocol built on Stacks using Clarity smart contracts.

## Project Structure
```
p2p-lending-pool/
├── contracts/
│   ├── p2p-lending-pool.clar       # Main lending pool contract
│   ├── credit-score.clar           # Credit scoring logic
│   ├── collateral-vault.clar       # Collateral management
│   ├── loan-terms.clar             # Loan terms and calculations
│   └── traits/
│       └── lending-traits.clar     # Shared traits across contracts
├── tests/
│   ├── p2p-lending-pool_test.ts    # Main contract tests
│   ├── credit-score_test.ts        # Credit scoring tests
│   ├── collateral-vault_test.ts    # Collateral tests
│   └── loan-terms_test.ts          # Loan terms tests
├── scripts/
│   ├── deploy.ts                   # Deployment scripts
│   └── setup-pool.ts               # Initial pool setup
├── README.md
└── package.json
```

## Features
- Deposit/withdraw funds
- Request loans with customizable duration
- Automated loan repayments
- Interest rate management
- Pool activity controls
- Built-in security measures

## Contract Details

### Constants
- Minimum deposit: 100 STX
- Maximum loan duration: 1 year (52,560 blocks)
- Maximum loan amount: 1M STX
- Pool fees: 2%

### Functions
```clarity
(deposit-funds (amount uint))
(withdraw-funds (amount uint))
(request-loan (amount uint) (duration uint))
(repay-loan (loan-id uint) (amount uint))
```

### Read-Only Functions
```clarity
(get-pool-details)
(get-lender-position (lender principal))
(get-loan-details (loan-id uint))
```

## Setup
1. Clone repository
2. Deploy contract to Stacks network
3. Initialize pool with `deposit-funds`

## Testing
Run tests:
```bash
clarinet test tests/p2p-lending-pool_test.ts
```

## Security
- Input validation
- Balance checks
- Duration limits
- Access controls
- Pool status management