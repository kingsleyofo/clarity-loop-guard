;; LoopGuard - IoT Node Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-revoked (err u103))
(define-constant err-group-not-found (err u104))
(define-constant err-already-in-group (err u105))

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
        group-id: (optional uint)
    }
)

(define-map node-activity
    principal
    (list 100 {
        timestamp: uint,
        action: (string-ascii 20)
    })
)

(define-map node-groups
    uint 
    {
        name: (string-ascii 20),
        description: (string-ascii 50),
        members: (list 100 principal),
        created-at: uint,
        settings: {
            auto-revoke: bool,
            inactivity-threshold: uint
        }
    }
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
            status: "active",
            group-id: none
        })
        
        (var-set total-nodes (+ (var-get total-nodes) u1))
        (log-activity node "registered")
        (ok true)
    )
)

(define-public (create-node-group 
    (name (string-ascii 20))
    (description (string-ascii 50))
    (auto-revoke bool)
    (inactivity-threshold uint)
)
    (let ((group-id (var-get total-groups)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            
            (map-set node-groups group-id {
                name: name,
                description: description,
                members: (list),
                created-at: block-height,
                settings: {
                    auto-revoke: auto-revoke,
                    inactivity-threshold: inactivity-threshold
                }
            })
            
            (var-set total-groups (+ group-id u1))
            (ok group-id)
        )
    )
)

(define-public (add-node-to-group (node principal) (group-id uint))
    (let ((node-data (unwrap! (map-get? nodes node) err-not-registered))
          (group-data (unwrap! (map-get? node-groups group-id) err-group-not-found)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (asserts! (is-none (get group-id node-data)) err-already-in-group)
            
            (map-set nodes node (merge node-data { group-id: (some group-id) }))
            (map-set node-groups group-id 
                (merge group-data {
                    members: (unwrap-panic (as-max-len? 
                        (append (get members group-data) node)
                        u100
                    ))
                })
            )
            (log-activity node (concat "added-to-group-" (to-string group-id)))
            (ok true)
        )
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
                        status: "active",
                        group-id: none
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
                        status: "active",
                        group-id: none
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

(define-read-only (get-group-info (group-id uint))
    (ok (map-get? node-groups group-id))
)

(define-read-only (get-total-groups)
    (ok (var-get total-groups))
)
