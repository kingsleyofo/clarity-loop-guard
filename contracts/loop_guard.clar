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

;; Rate limiting constants
(define-constant min-update-interval u10)
(define-constant valid-statuses (list "active" "running" "stopped" "maintenance" "error"))

;; Data Variables 
(define-data-var total-nodes uint u0)
(define-data-var total-groups uint u0)

;; Data Maps
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
        last-update: uint
    }
)

;; Additional maps and existing ones...
[Previous maps remain unchanged]

;; Enhanced Private Functions
(define-private (is-valid-status (status (string-ascii 20)))
    (unwrap-panic (index-of valid-statuses status))
)

(define-private (can-update-status (node principal))
    (let ((last-update (get last-update (default-to 
        { last-update: u0 } 
        (map-get? nodes node)))))
        (> (- block-height last-update) min-update-interval)
    )
)

(define-private (update-health-score (node principal) (status (string-ascii 20)))
    (let ((current-score (get health-score (default-to 
        { health-score: u100 } 
        (map-get? nodes node)))))
        (if (is-eq status "error")
            (- current-score u10)
            (min u100 (+ current-score u1))
        )
    )
)

;; New Batch Operation Function
(define-public (batch-update-status 
    (nodes (list 10 principal)) 
    (new-status (string-ascii 20)))
    (begin
        (asserts! (is-valid-status new-status) err-invalid-status)
        (fold check-and-update nodes (ok true))
    )
)

(define-private (check-and-update (node principal) (previous-result (response bool uint)))
    (if (is-ok previous-result)
        (begin
            (asserts! (is-registered node) err-not-registered)
            (asserts! (is-active node) err-revoked)
            (asserts! (can-update-status node) err-rate-limit)
            (update-node-status node new-status)
        )
        previous-result
    )
)

;; Enhanced Update Status Function
(define-public (update-node-status (node principal) (new-status (string-ascii 20)))
    (begin
        (asserts! (is-registered node) err-not-registered)
        (asserts! (is-active node) err-revoked)
        (asserts! (can-update-status node) err-rate-limit)
        (asserts! (is-valid-status new-status) err-invalid-status)
        
        (let ((health-score (update-health-score node new-status)))
            (map-set nodes node 
                (merge 
                    (default-to
                        {
                            registered: true,
                            active: true,
                            permissions: (list),
                            last-active: u0,
                            status: "active",
                            group-id: none,
                            health-score: u100,
                            last-update: u0
                        }
                        (map-get? nodes node)
                    )
                    {
                        last-active: block-height,
                        status: new-status,
                        health-score: health-score,
                        last-update: block-height
                    }
                )
            )
            (log-activity node new-status)
            (ok true)
        )
    )
)

[Remaining functions unchanged]
