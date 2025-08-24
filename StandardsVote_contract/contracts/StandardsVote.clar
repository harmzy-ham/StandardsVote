
;; title: StandardsVote
;; version: 1.0.0
;; summary: A voting system smart contract for industry standards approval
;; description: This contract allows registered voters to propose and vote on industry standards.
;;              Standards require a minimum quorum and approval threshold to pass.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-STANDARD-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-VOTING-CLOSED (err u104))
(define-constant ERR-INVALID-PROPOSAL (err u105))
(define-constant ERR-INSUFFICIENT-STAKE (err u106))

;; Voting parameters
(define-constant MIN-PROPOSAL-STAKE u1000000) ;; 1 STX in microSTX
(define-constant VOTING-DURATION u144) ;; ~1 day in blocks (assuming 10 min blocks)
(define-constant APPROVAL-THRESHOLD u60) ;; 60% approval needed
(define-constant MIN-QUORUM u20) ;; 20% of registered voters needed

;; data vars
(define-data-var next-standard-id uint u0)
(define-data-var total-registered-voters uint u0)

;; data maps
;; Registered voters who can participate in voting
(define-map registered-voters principal bool)

;; Standards proposals
(define-map standards
  { standard-id: uint }
  {
    title: (string-ascii 256),
    description: (string-utf8 1024),
    proposer: principal,
    created-at: uint,
    voting-ends-at: uint,
    votes-for: uint,
    votes-against: uint,
    total-votes: uint,
    status: (string-ascii 20) ;; "active", "passed", "rejected", "expired"
  }
)

;; Track who voted on which standard
(define-map votes
  { standard-id: uint, voter: principal }
  { vote: bool, voted-at: uint }
)

;; public functions

;; Register a new voter (only contract owner can do this initially)
(define-public (register-voter (voter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-none (map-get? registered-voters voter)) ERR-NOT-AUTHORIZED)
    (map-set registered-voters voter true)
    (var-set total-registered-voters (+ (var-get total-registered-voters) u1))
    (ok true)
  )
)

;; Propose a new standard
(define-public (propose-standard (title (string-ascii 256)) (description (string-utf8 1024)))
  (let
    (
      (standard-id (var-get next-standard-id))
      (current-block block-height)
    )
    (asserts! (is-some (map-get? registered-voters tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len title) u0) ERR-INVALID-PROPOSAL)
    (asserts! (> (len description) u0) ERR-INVALID-PROPOSAL)
    (asserts! (>= (stx-get-balance tx-sender) MIN-PROPOSAL-STAKE) ERR-INSUFFICIENT-STAKE)
    
    ;; Lock the proposal stake
    (try! (stx-transfer? MIN-PROPOSAL-STAKE tx-sender (as-contract tx-sender)))
    
    ;; Create the standard proposal
    (map-set standards
      { standard-id: standard-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        created-at: current-block,
        voting-ends-at: (+ current-block VOTING-DURATION),
        votes-for: u0,
        votes-against: u0,
        total-votes: u0,
        status: "active"
      }
    )
    
    ;; Increment the next standard ID
    (var-set next-standard-id (+ standard-id u1))
    (ok standard-id)
  )
)

;; Cast a vote on a standard
(define-public (vote-on-standard (standard-id uint) (vote bool))
  (let
    (
      (standard-data (unwrap! (map-get? standards { standard-id: standard-id }) ERR-STANDARD-NOT-FOUND))
      (current-block block-height)
    )
    ;; Check if voter is registered
    (asserts! (is-some (map-get? registered-voters tx-sender)) ERR-NOT-AUTHORIZED)
    
    ;; Check if voting is still active
    (asserts! (is-eq (get status standard-data) "active") ERR-VOTING-CLOSED)
    (asserts! (< current-block (get voting-ends-at standard-data)) ERR-VOTING-CLOSED)
    
    ;; Check if already voted
    (asserts! (is-none (map-get? votes { standard-id: standard-id, voter: tx-sender })) ERR-ALREADY-VOTED)
    
    ;; Record the vote
    (map-set votes
      { standard-id: standard-id, voter: tx-sender }
      { vote: vote, voted-at: current-block }
    )
    
    ;; Update vote counts
    (if vote
      (map-set standards
        { standard-id: standard-id }
        (merge standard-data {
          votes-for: (+ (get votes-for standard-data) u1),
          total-votes: (+ (get total-votes standard-data) u1)
        })
      )
      (map-set standards
        { standard-id: standard-id }
        (merge standard-data {
          votes-against: (+ (get votes-against standard-data) u1),
          total-votes: (+ (get total-votes standard-data) u1)
        })
      )
    )
    (ok true)
  )
)

;; Finalize voting on a standard (can be called by anyone after voting period ends)
(define-public (finalize-standard (standard-id uint))
  (let
    (
      (standard-data (unwrap! (map-get? standards { standard-id: standard-id }) ERR-STANDARD-NOT-FOUND))
      (current-block block-height)
      (total-voters (var-get total-registered-voters))
      (votes-for (get votes-for standard-data))
      (total-votes (get total-votes standard-data))
      (quorum-met (>= (* total-votes u100) (* total-voters MIN-QUORUM)))
      (approval-met (>= (* votes-for u100) (* total-votes APPROVAL-THRESHOLD)))
    )
    ;; Check if voting period has ended
    (asserts! (>= current-block (get voting-ends-at standard-data)) ERR-VOTING-CLOSED)
    (asserts! (is-eq (get status standard-data) "active") ERR-VOTING-CLOSED)
    
    ;; Determine final status
    (let
      (
        (final-status 
          (if (and quorum-met approval-met)
            "passed"
            "rejected"
          )
        )
      )
      ;; Update standard status
      (map-set standards
        { standard-id: standard-id }
        (merge standard-data { status: final-status })
      )
      
      ;; If standard passed, return stake to proposer, otherwise keep it
      (if (is-eq final-status "passed")
        (as-contract (stx-transfer? MIN-PROPOSAL-STAKE tx-sender (get proposer standard-data)))
        (ok true)
      )
    )
  )
)

;; read only functions

;; Get standard details
(define-read-only (get-standard (standard-id uint))
  (map-get? standards { standard-id: standard-id })
)

;; Check if a voter is registered
(define-read-only (is-registered-voter (voter principal))
  (default-to false (map-get? registered-voters voter))
)

;; Get vote details for a voter on a specific standard
(define-read-only (get-vote (standard-id uint) (voter principal))
  (map-get? votes { standard-id: standard-id, voter: voter })
)

;; Get total number of registered voters
(define-read-only (get-total-registered-voters)
  (var-get total-registered-voters)
)

;; Get next standard ID
(define-read-only (get-next-standard-id)
  (var-get next-standard-id)
)

;; Check if voting is still active for a standard
(define-read-only (is-voting-active (standard-id uint))
  (match (map-get? standards { standard-id: standard-id })
    standard-data 
    (and 
      (is-eq (get status standard-data) "active")
      (< block-height (get voting-ends-at standard-data))
    )
    false
  )
)

;; Get voting statistics for a standard
(define-read-only (get-voting-stats (standard-id uint))
  (match (map-get? standards { standard-id: standard-id })
    standard-data 
    (some {
      votes-for: (get votes-for standard-data),
      votes-against: (get votes-against standard-data),
      total-votes: (get total-votes standard-data),
      approval-percentage: (if (> (get total-votes standard-data) u0)
        (/ (* (get votes-for standard-data) u100) (get total-votes standard-data))
        u0
      ),
      quorum-percentage: (/ (* (get total-votes standard-data) u100) (var-get total-registered-voters))
    })
    none
  )
)

;; private functions

;; Check if quorum is met for a standard
(define-private (is-quorum-met (total-votes uint))
  (>= (* total-votes u100) (* (var-get total-registered-voters) MIN-QUORUM))
)

;; Check if approval threshold is met for a standard
(define-private (is-approval-met (votes-for uint) (total-votes uint))
  (if (> total-votes u0)
    (>= (* votes-for u100) (* total-votes APPROVAL-THRESHOLD))
    false
  )
)
