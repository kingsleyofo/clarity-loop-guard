;; LoopGuard - IoT Node Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-revoked (err u103))

;; Data Variables 
(define-data-var total-nodes uint u0)

;; Data Maps
(define-map nodes 
    principal 
    {
        registered: bool,
        active: bool,
        permissions: (list 10 uint),
        last-active: uint,
        status: (string-ascii 20)
    }
)

(define-map node-activity
    principal
    (list 100 {
        timestamp: uint,
        action: (string-ascii 20)
    })
)

;; Private Functions
(define-private (is-registered (node principal))
    (default-to false (get registered (map-get? nodes node)))
)

(define-private (is-active (node principal))
    (default-to false (get active (map-get? nodes node)))
)

(define-private (log-activity (node principal) (action (string-ascii 20)))
    (let ((current-time block-height))
        (map-set node-activity 
            node
            (unwrap-panic (as-max-len? 
                (append 
                    (default-to (list) (map-get? node-activity node))
                    {
                        timestamp: current-time,
                        action: action
                    }
                )
                u100
            ))
        )
    )
)

;; Public Functions
(define-public (register-node (node principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (is-registered node)) err-already-registered)
        
        (map-set nodes node {
            registered: true,
            active: true,
            permissions: (list),
            last-active: block-height,
            status: "active"
        })
        
        (var-set total-nodes (+ (var-get total-nodes) u1))
        (log-activity node "registered")
        (ok true)
    )
)

(define-public (revoke-node (node principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-registered node) err-not-registered)
        
        (map-set nodes node 
            (merge 
                (default-to 
                    {
                        registered: true,
                        active: true,
                        permissions: (list),
                        last-active: u0,
                        status: "active"
                    }
                    (map-get? nodes node)
                )
                {
                    active: false,
                    status: "revoked"
                }
            )
        )
        (log-activity node "revoked")
        (ok true)
    )
)

(define-public (update-node-status (node principal) (new-status (string-ascii 20)))
    (begin
        (asserts! (is-registered node) err-not-registered)
        (asserts! (is-active node) err-revoked)
        
        (map-set nodes node 
            (merge 
                (default-to
                    {
                        registered: true,
                        active: true,
                        permissions: (list),
                        last-active: u0,
                        status: "active"
                    }
                    (map-get? nodes node)
                )
                {
                    last-active: block-height,
                    status: new-status
                }
            )
        )
        (log-activity node new-status)
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-node-info (node principal))
    (ok (map-get? nodes node))
)

(define-read-only (get-node-activity (node principal))
    (ok (map-get? node-activity node))
)

(define-read-only (get-total-nodes)
    (ok (var-get total-nodes))
)