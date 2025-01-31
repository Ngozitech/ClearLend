;; Error codes
(define-constant ERR-UNAUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))
(define-constant ERR-POOL-INACTIVE (err u1003))
(define-constant ERR-LOAN-NOT-FOUND (err u1004))
(define-constant ERR-INVALID-DURATION (err u1005))
(define-constant ERR-MAX-AMOUNT-EXCEEDED (err u1006))

;; Constants
(define-constant MIN-DEPOSIT u100000000) ;; 100 STX minimum deposit
(define-constant MAX-LOAN-DURATION u52560) ;; max 1 year (52560 blocks, assuming 10 min/block)
(define-constant MAX-LOAN-AMOUNT u1000000000000) ;; 1M STX
(define-constant CONTRACT-OWNER tx-sender)
(define-constant POOL-FEES u20) ;; 2% fees (represented as 20 basis points)

;; Data vars
(define-data-var total-pool-balance uint u0)
(define-data-var pool-active bool true)
(define-data-var total-loans uint u0)

;; Data maps
(define-map lender-positions
    principal
    {
        balance: uint,
        deposited-at: uint,
        last-interest-claim: uint
    }
)

(define-map active-loans
    uint  ;; loan ID
    {
        borrower: principal,
        amount: uint,
        interest-rate: uint,
        start-height: uint,
        end-height: uint,
        total-repaid: uint,
        status: (string-ascii 20)
    }
)

;; Public functions

;; Deposit funds into lending pool
(define-public (deposit-funds (amount uint))
    (let
        (
            (sender tx-sender)
            (current-height block-height)
        )
        (asserts! (>= amount MIN-DEPOSIT) ERR-INVALID-AMOUNT)
        (asserts! (is-pool-active) ERR-POOL-INACTIVE)
        
        ;; Transfer STX from sender to contract
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        
        ;; Update lender position
        (match (map-get? lender-positions sender)
            existing-position (map-set lender-positions
                sender
                {
                    balance: (+ amount (get balance existing-position)),
                    deposited-at: current-height,
                    last-interest-claim: current-height
                }
            )
            ;; If no existing position, create new one
            (map-set lender-positions
                sender
                {
                    balance: amount,
                    deposited-at: current-height,
                    last-interest-claim: current-height
                }
            )
        )
        
        ;; Update total pool balance
        (var-set total-pool-balance (+ (var-get total-pool-balance) amount))
        (ok true)
    )
)

;; Withdraw funds from lending pool
(define-public (withdraw-funds (amount uint))
    (let
        (
            (sender tx-sender)
            (position (unwrap! (map-get? lender-positions sender) ERR-UNAUTHORIZED))
        )
        (asserts! (is-pool-active) ERR-POOL-INACTIVE)
        (asserts! (<= amount (get balance position)) ERR-INSUFFICIENT-BALANCE)
        
        ;; Transfer STX from contract to sender
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) sender)))
        
        ;; Update lender position
        (map-set lender-positions
            sender
            {
                balance: (- (get balance position) amount),
                deposited-at: (get deposited-at position),
                last-interest-claim: (get last-interest-claim position)
            }
        )
        
        ;; Update total pool balance
        (var-set total-pool-balance (- (var-get total-pool-balance) amount))
        (ok true)
    )
)

;; Request loan
(define-public (request-loan (amount uint) (duration uint))
    (let
        (
            (loan-id (+ (var-get total-loans) u1))
            (sender tx-sender)
            (current-height block-height)
        )
        (asserts! (is-pool-active) ERR-POOL-INACTIVE)
        (asserts! (<= amount (var-get total-pool-balance)) ERR-INSUFFICIENT-BALANCE)
        (asserts! (<= amount MAX-LOAN-AMOUNT) ERR-MAX-AMOUNT-EXCEEDED)
        (asserts! (<= duration MAX-LOAN-DURATION) ERR-INVALID-DURATION)
        
        ;; Create new loan
        (map-set active-loans
            loan-id
            {
                borrower: sender,
                amount: amount,
                interest-rate: u100, ;; 10% fixed rate for now
                start-height: current-height,
                end-height: (+ current-height duration),
                total-repaid: u0,
                status: "ACTIVE"
            }
        )
        
        ;; Update total loans counter
        (var-set total-loans loan-id)
        
        ;; Transfer STX to borrower
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) sender)))
        (ok loan-id)
    )
)

;; Repay loan
(define-public (repay-loan (loan-id uint) (amount uint))
    (let
        (
            (loan (unwrap! (map-get? active-loans loan-id) ERR-LOAN-NOT-FOUND))
            (sender tx-sender)
            (remaining-amount (- (get amount loan) (get total-repaid loan)))
        )
        (asserts! (is-eq sender (get borrower loan)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status loan) "ACTIVE") ERR-LOAN-NOT-FOUND)
        (asserts! (<= amount remaining-amount) ERR-INVALID-AMOUNT)
        
        ;; Transfer STX from sender to contract
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        
        ;; Update loan repayment amount
        (map-set active-loans
            loan-id
            (merge loan { total-repaid: (+ (get total-repaid loan) amount) })
        )
        
        ;; Update pool balance
        (var-set total-pool-balance (+ (var-get total-pool-balance) amount))
        (ok true)
    )
)

;; Read-only functions

;; Get pool details
(define-read-only (get-pool-details)
    (ok {
        total-balance: (var-get total-pool-balance),
        total-loans: (var-get total-loans),
        active: (var-get pool-active),
        min-deposit: MIN-DEPOSIT
    })
)

;; Get lender position
(define-read-only (get-lender-position (lender principal))
    (map-get? lender-positions lender)
)

;; Get loan details
(define-read-only (get-loan-details (loan-id uint))
    (map-get? active-loans loan-id)
)

;; Private functions

;; Check if pool is active
(define-private (is-pool-active)
    (var-get pool-active)
)

;; Admin functions

;; Toggle pool status (only contract owner)
(define-public (toggle-pool-status)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (ok (var-set pool-active (not (var-get pool-active))))
    )
)