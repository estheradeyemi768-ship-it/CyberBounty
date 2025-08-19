;; CyberBounty BountyFactory Contract
;; Clarity v2 (assuming latest syntax as of 2025, using traits where possible)
;; Implements creation and management of bounty programs with escrowed rewards
;; Supports STX escrow for simplicity; extendable to SIP-10 tokens
;; Sophisticated features: bounty lifecycle (create, fund, update, close), reward tiers, scopes, events, admin controls, pause

(define-trait sip10-trait
  (
    (transfer (principal principal uint (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INSUFFICIENT-FUNDS u101)
(define-constant ERR-BOUNTY-NOT-FOUND u102)
(define-constant ERR-BOUNTY-CLOSED u103)
(define-constant ERR-PAUSED u104)
(define-constant ERR-INVALID-AMOUNT u105)
(define-constant ERR-INVALID-SEVERITY u106)
(define-constant ERR-ZERO-ADDRESS u107)
(define-constant ERR-ALREADY-EXISTS u108)
(define-constant ERR-INVALID-SCOPE u109)

;; Severity levels as constants for reward tiers
(define-constant SEVERITY-LOW u1)
(define-constant SEVERITY-MEDIUM u2)
(define-constant SEVERITY-HIGH u3)
(define-constant SEVERITY-CRITICAL u4)

;; Admin and contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var bounty-counter uint u0)
(define-data-var total-escrowed uint u0)

;; Maps
(define-map bounties uint
  {
    creator: principal,
    description: (string-utf8 256),
    scopes: (list 10 (string-ascii 128)), ;; e.g., "smart-contracts", "web-apps"
    reward-tiers: (tuple (low uint) (medium uint) (high uint) (critical uint)),
    escrowed: uint,
    active: bool,
    created-at: uint,
    closed-at: (optional uint)
  }
)

(define-map bounty-funds uint uint) ;; Escrowed STX per bounty (in microstacks)

;; Events (using print for logging)
(define-private (emit-event (event-name (string-ascii 32)) (data (tuple (bounty-id uint) (amount uint) (sender principal))))
  (print { event: event-name, data: data })
)

;; Private helper: is-admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: ensure not paused
(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;; Private helper: validate severity
(define-private (validate-severity (sev uint))
  (or (is-eq sev SEVERITY-LOW) (is-eq sev SEVERITY-MEDIUM) (is-eq sev SEVERITY-HIGH) (is-eq sev SEVERITY-CRITICAL))
)

;; Private helper: get-reward-for-severity (tiers (tuple (low uint) (medium uint) (high uint) (critical uint)) (sev uint))
(define-private (get-reward-for-severity (tiers (tuple (low uint) (medium uint) (high uint) (critical uint))) (sev uint))
  (if (is-eq sev SEVERITY-LOW) (get low tiers)
    (if (is-eq sev SEVERITY-MEDIUM) (get medium tiers)
      (if (is-eq sev SEVERITY-HIGH) (get high tiers)
        (get critical tiers))))
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-admin tx-sender)) (err ERR-ZERO-ADDRESS)) ;; Avoid self-transfer for safety
    (var-set admin new-admin)
    (ok true)
  )
)

;; Pause/unpause the contract
(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set paused pause)
    (ok pause)
  )
)

;; Create a new bounty program
(define-public (create-bounty (description (string-utf8 256)) (scopes (list 10 (string-ascii 128))) (reward-low uint) (reward-medium uint) (reward-high uint) (reward-critical uint) (initial-fund uint))
  (begin
    (ensure-not-paused)
    (asserts! (> (len scopes) u0) (err ERR-INVALID-SCOPE))
    (asserts! (> initial-fund u0) (err ERR-INVALID-AMOUNT))
    (let ((bounty-id (+ (var-get bounty-counter) u1)))
      (asserts! (is-none (map-get? bounties bounty-id)) (err ERR-ALREADY-EXISTS))
      (try! (stx-transfer? initial-fund tx-sender (as-contract tx-sender)))
      (map-set bounties bounty-id
        {
          creator: tx-sender,
          description: description,
          scopes: scopes,
          reward-tiers: { low: reward-low, medium: reward-medium, high: reward-high, critical: reward-critical },
          escrowed: initial-fund,
          active: true,
          created-at: block-height,
          closed-at: none
        }
      )
      (map-set bounty-funds bounty-id initial-fund)
      (var-set bounty-counter bounty-id)
      (var-set total-escrowed (+ (var-get total-escrowed) initial-fund))
      (emit-event "bounty-created" { bounty-id: bounty-id, amount: initial-fund, sender: tx-sender })
      (ok bounty-id)
    )
  )
)

;; Fund an existing bounty
(define-public (fund-bounty (bounty-id uint) (amount uint))
  (begin
    (ensure-not-paused)
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (let ((bounty (unwrap! (map-get? bounties bounty-id) (err ERR-BOUNTY-NOT-FOUND))))
      (asserts! (get active bounty) (err ERR-BOUNTY-CLOSED))
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set bounties bounty-id (merge bounty { escrowed: (+ (get escrowed bounty) amount) }))
      (map-set bounty-funds bounty-id (+ (unwrap-panic (map-get? bounty-funds bounty-id)) amount))
      (var-set total-escrowed (+ (var-get total-escrowed) amount))
      (emit-event "bounty-funded" { bounty-id: bounty-id, amount: amount, sender: tx-sender })
      (ok true)
    )
  )
)

;; Update bounty reward tiers (only creator)
(define-public (update-reward-tiers (bounty-id uint) (reward-low uint) (reward-medium uint) (reward-high uint) (reward-critical uint))
  (begin
    (ensure-not-paused)
    (let ((bounty (unwrap! (map-get? bounties bounty-id) (err ERR-BOUNTY-NOT-FOUND))))
      (asserts! (is-eq (get creator bounty) tx-sender) (err ERR-NOT-AUTHORIZED))
      (asserts! (get active bounty) (err ERR-BOUNTY-CLOSED))
      (map-set bounties bounty-id
        (merge bounty {
          reward-tiers: { low: reward-low, medium: reward-medium, high: reward-high, critical: reward-critical }
        })
      )
      (emit-event "tiers-updated" { bounty-id: bounty-id, amount: u0, sender: tx-sender })
      (ok true)
    )
  )
)

;; Close a bounty (only creator, refunds remaining escrow)
(define-public (close-bounty (bounty-id uint))
  (begin
    (ensure-not-paused)
    (let ((bounty (unwrap! (map-get? bounties bounty-id) (err ERR-BOUNTY-NOT-FOUND))))
      (asserts! (is-eq (get creator bounty) tx-sender) (err ERR-NOT-AUTHORIZED))
      (asserts! (get active bounty) (err ERR-BOUNTY-CLOSED))
      (let ((remaining (unwrap-panic (map-get? bounty-funds bounty-id))))
        (if (> remaining u0)
          (as-contract (try! (stx-transfer? remaining tx-sender (get creator bounty))))
          (ok true)
        )
        (map-set bounties bounty-id
          (merge bounty { active: false, closed-at: (some block-height) })
        )
        (map-delete bounty-funds bounty-id)
        (var-set total-escrowed (- (var-get total-escrowed) remaining))
        (emit-event "bounty-closed" { bounty-id: bounty-id, amount: remaining, sender: tx-sender })
        (ok true)
      )
    )
  )
)

;; Withdraw funds from bounty (internal, for payouts in other contracts)
(define-private (withdraw-for-payout (bounty-id uint) (amount uint) (recipient principal))
  (begin
    (let ((bounty (unwrap-panic (map-get? bounties bounty-id))))
      (asserts! (get active bounty) (err ERR-BOUNTY-CLOSED))
      (asserts! (>= (unwrap-panic (map-get? bounty-funds bounty-id)) amount) (err ERR-INSUFFICIENT-FUNDS))
      (as-contract (try! (stx-transfer? amount tx-sender recipient)))
      (map-set bounty-funds bounty-id (- (unwrap-panic (map-get? bounty-funds bounty-id)) amount))
      (map-set bounties bounty-id (merge bounty { escrowed: (- (get escrowed bounty) amount) }))
      (var-set total-escrowed (- (var-get total-escrowed) amount))
      (emit-event "payout-withdrawn" { bounty-id: bounty-id, amount: amount, sender: recipient })
      (ok true)
    )
  )
)

;; Read-only: get bounty details
(define-read-only (get-bounty (bounty-id uint))
  (ok (map-get? bounties bounty-id))
)

;; Read-only: get bounty escrow
(define-read-only (get-bounty-escrow (bounty-id uint))
  (ok (default-to u0 (map-get? bounty-funds bounty-id)))
)

;; Read-only: get total escrowed across all bounties
(define-read-only (get-total-escrowed)
  (ok (var-get total-escrowed))
)

;; Read-only: get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)

;; Read-only: get bounty counter
(define-read-only (get-bounty-counter)
  (ok (var-get bounty-counter))
)

;; Read-only: calculate reward for a severity
(define-read-only (get-reward (bounty-id uint) (severity uint))
  (let ((bounty (unwrap! (map-get? bounties bounty-id) (err ERR-BOUNTY-NOT-FOUND))))
    (asserts! (validate-severity severity) (err ERR-INVALID-SEVERITY))
    (ok (get-reward-for-severity (get reward-tiers bounty) severity))
  )
)

;; Extension point: Fund with SIP-10 token (example, requires trait)
(define-public (fund-with-token (bounty-id uint) (amount uint) (token-contract <sip10-trait>))
  (begin
    (ensure-not-paused)
    (let ((bounty (unwrap! (map-get? bounties bounty-id) (err ERR-BOUNTY-NOT-FOUND))))
      (asserts! (get active bounty) (err ERR-BOUNTY-CLOSED))
      (try! (contract-call? token-contract transfer tx-sender (as-contract tx-sender) amount none))
      ;; Note: Would need separate map for token escrows, omitted for brevity
      (ok true)
    )
  )
)