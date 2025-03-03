;; LoopGuard - IoT Node Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-revoked (err u103))
(define-constant err-group-not-found (err u104))
(define-constant err-already-in-group (err u105))
(define-constant err-rate-limit (err u106))
(define-constant err-invalid-status (err u107))
(define-constant err-history-full (err u108))

;; Rate limiting constants
(define-constant min-update-interval u10)
(define-constant valid-statuses (list "active" "running" "stopped" "maintenance" "error"))
(define-constant max-history-length u50)

;; Data Variables 
(define-data-var total-nodes uint u0)
(define-data-var total-groups uint u0)

;; Enhanced Data Maps
(define-map nodes 
    principal 
    {
        registered: bool,
        active: bool,
        permissions: (list 10 uint),
        last-active: uint,
        status: (string-ascii 20),
        group-id: (optional uint),
        health-score: uint,
        last-update: uint,
        update-count: uint
    }
)

;; New Status History Map
(define-map status-history
    principal
    {
        entries: (list 50 {
            status: (string-ascii 20),
            timestamp: uint,
            blocks-in-status: uint
        })
    }
)

;; Enhanced Private Functions
(define-private (get-adaptive-interval (node principal))
    (let ((node-data (unwrap! (map-get? nodes node) u0)))
        (if (< (get health-score node-data) u50)
            (* min-update-interval u2)
            min-update-interval
        )
    )
)

(define-private (add-status-history (node principal) (new-status (string-ascii 20)))
    (let (
        (current-history (default-to { entries: (list) } (map-get? status-history node)))
        (new-entry {
            status: new-status,
            timestamp: block-height,
            blocks-in-status: u0
        })
    )
        (if (>= (len (get entries current-history)) max-history-length)
            (err err-history-full)
            (ok (map-set status-history node {
                entries: (append (get entries current-history) new-entry)
            }))
        )
    )
)

(define-private (calculate-health-score (node principal) (status (string-ascii 20)))
    (let (
        (node-data (unwrap! (map-get? nodes node) u0))
        (base-score (get health-score node-data))
        (update-count (get update-count node-data))
    )
        (cond
            ((is-eq status "error") (- base-score u10))
            ((is-eq status "maintenance") (- base-score u5))
            ((> update-count u100) (min u100 (+ base-score u2)))
            (true (min u100 (+ base-score u1)))
        )
    )
)

;; Enhanced Update Status Function
(define-public (update-node-status (node principal) (new-status (string-ascii 20)))
    (begin
        (asserts! (is-registered node) err-not-registered)
        (asserts! (is-active node) err-revoked)
        (asserts! (>= (- block-height (get last-update (default-to 
            { last-update: u0 } 
            (map-get? nodes node)))) (get-adaptive-interval node)) err-rate-limit)
        (asserts! (is-valid-status new-status) err-invalid-status)
        
        (let (
            (health-score (calculate-health-score node new-status))
            (node-data (unwrap! (map-get? nodes node) 
                {
                    registered: true,
                    active: true,
                    permissions: (list),
                    last-active: u0,
                    status: "active",
                    group-id: none,
                    health-score: u100,
                    last-update: u0,
                    update-count: u0
                }))
        )
            (try! (add-status-history node new-status))
            (map-set nodes node 
                (merge node-data
                    {
                        last-active: block-height,
                        status: new-status,
                        health-score: health-score,
                        last-update: block-height,
                        update-count: (+ (get update-count node-data) u1)
                    }
                )
            )
            (ok true)
        )
    )
)

[Remaining functions unchanged]
