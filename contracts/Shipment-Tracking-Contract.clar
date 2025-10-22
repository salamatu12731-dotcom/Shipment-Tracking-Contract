(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-shipment-exists (err u104))
(define-constant err-invalid-participant (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-escrow-not-funded (err u107))
(define-constant err-insurance-required (err u108))
(define-constant err-claim-already-exists (err u109))
(define-constant err-claim-not-found (err u110))
(define-constant err-invalid-claim-status (err u111))
(define-constant err-invalid-rating (err u112))
(define-constant err-rating-already-exists (err u113))
(define-constant err-invalid-rated-user (err u114))

(define-data-var next-shipment-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var next-rating-id uint u1)
(define-data-var platform-fee-rate uint u250)
(define-data-var insurance-rate uint u500)

(define-map shipments
    { shipment-id: uint }
    {
        sender: principal,
        receiver: principal,
        carrier: principal,
        status: (string-ascii 20),
        origin: (string-ascii 100),
        destination: (string-ascii 100),
        created-at: uint,
        updated-at: uint,
        estimated-delivery: uint,
        actual-delivery: (optional uint),
        value: uint,
        weight: uint,
        tracking-hash: (string-ascii 64),
        escrow-amount: uint,
        insurance-amount: uint,
        requires-insurance: bool,
    }
)

(define-map shipment-updates
    {
        shipment-id: uint,
        update-id: uint,
    }
    {
        status: (string-ascii 20),
        location: (string-ascii 100),
        timestamp: uint,
        updater: principal,
        notes: (string-ascii 200),
    }
)

(define-map shipment-update-count
    { shipment-id: uint }
    { count: uint }
)

(define-map authorized-carriers
    { carrier: principal }
    {
        authorized: bool,
        name: (string-ascii 50),
    }
)

(define-map user-shipments
    {
        user: principal,
        shipment-id: uint,
    }
    { role: (string-ascii 10) }
)

(define-map escrow-balances
    { shipment-id: uint }
    {
        amount: uint,
        released: bool,
        release-block: (optional uint),
    }
)

(define-map insurance-policies
    { shipment-id: uint }
    {
        premium-paid: uint,
        coverage-amount: uint,
        active: bool,
        policy-holder: principal,
    }
)

(define-map insurance-claims
    { claim-id: uint }
    {
        shipment-id: uint,
        claimant: principal,
        amount-claimed: uint,
        reason: (string-ascii 200),
        status: (string-ascii 20),
        filed-at: uint,
        resolved-at: (optional uint),
        approved-amount: uint,
    }
)

(define-map shipment-claims
    { shipment-id: uint }
    { claim-id: (optional uint) }
)

(define-map ratings
    { rating-id: uint }
    {
        shipment-id: uint,
        rater: principal,
        rated-user: principal,
        score: uint,
        timestamp: uint,
    }
)

(define-map rating-totals
    { user: principal }
    { total-score: uint }
)

(define-map rating-counts
    { user: principal }
    { count: uint }
)

(define-map user-ratings
    {
        shipment-id: uint,
        rater: principal,
    }
    { rating-id: uint }
)

(define-read-only (get-user-average-rating (user principal))
    (let (
            (total (default-to u0
                (get total-score (map-get? rating-totals { user: user }))
            ))
            (count (default-to u0 (get count (map-get? rating-counts { user: user }))))
        )
        (if (> count u0)
            (/ total count)
            u0
        )
    )
)

(define-read-only (get-user-rating-count (user principal))
    (default-to u0 (get count (map-get? rating-counts { user: user })))
)

(define-read-only (get-rating-by-id (rating-id uint))
    (map-get? ratings { rating-id: rating-id })
)

(define-read-only (get-shipment-rating
        (shipment-id uint)
        (rater principal)
    )
    (match (map-get? user-ratings {
        shipment-id: shipment-id,
        rater: rater,
    })
        rating-record (map-get? ratings { rating-id: (get rating-id rating-record) })
        none
    )
)

(define-read-only (get-shipment (shipment-id uint))
    (map-get? shipments { shipment-id: shipment-id })
)

(define-read-only (get-shipment-updates (shipment-id uint))
    (let ((update-count (default-to u0
            (get count
                (map-get? shipment-update-count { shipment-id: shipment-id })
            ))))
        (map get-update-by-id (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
    )
)

(define-read-only (get-update-by-id (update-id uint))
    (map-get? shipment-updates {
        shipment-id: u1,
        update-id: update-id,
    })
)

(define-read-only (is-authorized-carrier (carrier principal))
    (default-to false
        (get authorized (map-get? authorized-carriers { carrier: carrier }))
    )
)

(define-read-only (get-user-role
        (user principal)
        (shipment-id uint)
    )
    (get role
        (map-get? user-shipments {
            user: user,
            shipment-id: shipment-id,
        })
    )
)

(define-read-only (can-update-shipment
        (user principal)
        (shipment-id uint)
    )
    (let (
            (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) false))
            (user-role (get-user-role user shipment-id))
        )
        (or
            (is-eq user (get sender shipment))
            (is-eq user (get receiver shipment))
            (is-eq user (get carrier shipment))
            (is-authorized-carrier user)
        )
    )
)

(define-public (authorize-carrier
        (carrier principal)
        (name (string-ascii 50))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set authorized-carriers { carrier: carrier } {
            authorized: true,
            name: name,
        }))
    )
)

(define-public (revoke-carrier (carrier principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set authorized-carriers { carrier: carrier } {
            authorized: false,
            name: "",
        }))
    )
)

(define-public (create-shipment
        (receiver principal)
        (carrier principal)
        (origin (string-ascii 100))
        (destination (string-ascii 100))
        (estimated-delivery uint)
        (value uint)
        (weight uint)
        (tracking-hash (string-ascii 64))
        (escrow-amount uint)
        (requires-insurance bool)
    )
    (let (
            (shipment-id (var-get next-shipment-id))
            (current-block stacks-block-height)
            (insurance-amount (if requires-insurance
                (/ (* value (var-get insurance-rate)) u10000)
                u0
            ))
            (total-payment (+ escrow-amount insurance-amount))
        )
        (asserts! (is-authorized-carrier carrier) err-unauthorized)
        (asserts! (> estimated-delivery current-block) err-invalid-status)
        (asserts! (>= (stx-get-balance tx-sender) total-payment)
            err-insufficient-funds
        )
        (asserts! (> escrow-amount u0) err-escrow-not-funded)
        (asserts! (or (not requires-insurance) (> insurance-amount u0))
            err-insurance-required
        )

        (if (> total-payment u0)
            (unwrap!
                (stx-transfer? total-payment tx-sender (as-contract tx-sender))
                (err u999)
            )
            true
        )

        (map-set shipments { shipment-id: shipment-id } {
            sender: tx-sender,
            receiver: receiver,
            carrier: carrier,
            status: "created",
            origin: origin,
            destination: destination,
            created-at: current-block,
            updated-at: current-block,
            estimated-delivery: estimated-delivery,
            actual-delivery: none,
            value: value,
            weight: weight,
            tracking-hash: tracking-hash,
            escrow-amount: escrow-amount,
            insurance-amount: insurance-amount,
            requires-insurance: requires-insurance,
        })

        (map-set escrow-balances { shipment-id: shipment-id } {
            amount: escrow-amount,
            released: false,
            release-block: none,
        })

        (if requires-insurance
            (map-set insurance-policies { shipment-id: shipment-id } {
                premium-paid: insurance-amount,
                coverage-amount: value,
                active: true,
                policy-holder: tx-sender,
            })
            true
        )

        (map-set user-shipments {
            user: tx-sender,
            shipment-id: shipment-id,
        } { role: "sender" }
        )
        (map-set user-shipments {
            user: receiver,
            shipment-id: shipment-id,
        } { role: "receiver" }
        )
        (map-set user-shipments {
            user: carrier,
            shipment-id: shipment-id,
        } { role: "carrier" }
        )
        (map-set shipment-update-count { shipment-id: shipment-id } { count: u0 })

        (var-set next-shipment-id (+ shipment-id u1))
        (add-shipment-update shipment-id "created" origin
            "Shipment created and ready for pickup"
        )
    )
)

(define-public (update-shipment-status
        (shipment-id uint)
        (new-status (string-ascii 20))
        (location (string-ascii 100))
        (notes (string-ascii 200))
    )
    (let (
            (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id })
                err-not-found
            ))
            (current-block stacks-block-height)
        )
        (asserts! (can-update-shipment tx-sender shipment-id) err-unauthorized)
        (asserts! (is-valid-status new-status) err-invalid-status)

        (map-set shipments { shipment-id: shipment-id }
            (merge shipment {
                status: new-status,
                updated-at: current-block,
                actual-delivery: (if (is-eq new-status "delivered")
                    (some current-block)
                    (get actual-delivery shipment)
                ),
            })
        )

        (add-shipment-update shipment-id new-status location notes)
    )
)

(define-private (add-shipment-update
        (shipment-id uint)
        (status (string-ascii 20))
        (location (string-ascii 100))
        (notes (string-ascii 200))
    )
    (let (
            (current-count (default-to u0
                (get count
                    (map-get? shipment-update-count { shipment-id: shipment-id })
                )))
            (new-count (+ current-count u1))
        )
        (map-set shipment-updates {
            shipment-id: shipment-id,
            update-id: new-count,
        } {
            status: status,
            location: location,
            timestamp: stacks-block-height,
            updater: tx-sender,
            notes: notes,
        })

        (map-set shipment-update-count { shipment-id: shipment-id } { count: new-count })
        (ok new-count)
    )
)

(define-read-only (is-valid-status (status (string-ascii 20)))
    (or
        (is-eq status "created")
        (is-eq status "picked-up")
        (is-eq status "in-transit")
        (is-eq status "out-for-delivery")
        (is-eq status "delivered")
        (is-eq status "exception")
        (is-eq status "returned")
        (is-eq status "cancelled")
    )
)

(define-public (pickup-shipment
        (shipment-id uint)
        (location (string-ascii 100))
    )
    (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get carrier shipment)) err-unauthorized)
        (asserts! (is-eq (get status shipment) "created") err-invalid-status)
        (update-shipment-status shipment-id "picked-up" location
            "Package picked up by carrier"
        )
    )
)

(define-public (mark-in-transit
        (shipment-id uint)
        (location (string-ascii 100))
    )
    (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get carrier shipment)) err-unauthorized)
        (asserts! (is-eq (get status shipment) "picked-up") err-invalid-status)
        (update-shipment-status shipment-id "in-transit" location
            "Package in transit to destination"
        )
    )
)

(define-public (mark-out-for-delivery
        (shipment-id uint)
        (location (string-ascii 100))
    )
    (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get carrier shipment)) err-unauthorized)
        (asserts! (is-eq (get status shipment) "in-transit") err-invalid-status)
        (update-shipment-status shipment-id "out-for-delivery" location
            "Package out for delivery"
        )
    )
)

(define-public (deliver-shipment
        (shipment-id uint)
        (location (string-ascii 100))
    )
    (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get carrier shipment)) err-unauthorized)
        (asserts! (is-eq (get status shipment) "out-for-delivery")
            err-invalid-status
        )
        (update-shipment-status shipment-id "delivered" location
            "Package successfully delivered"
        )
    )
)

(define-public (report-exception
        (shipment-id uint)
        (location (string-ascii 100))
        (reason (string-ascii 200))
    )
    (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found)))
        (asserts! (can-update-shipment tx-sender shipment-id) err-unauthorized)
        (update-shipment-status shipment-id "exception" location reason)
    )
)

(define-public (confirm-delivery (shipment-id uint))
    (let (
            (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id })
                err-not-found
            ))
            (escrow-data (unwrap! (map-get? escrow-balances { shipment-id: shipment-id })
                err-not-found
            ))
        )
        (asserts! (is-eq tx-sender (get receiver shipment)) err-unauthorized)
        (asserts! (is-eq (get status shipment) "delivered") err-invalid-status)
        (asserts! (not (get released escrow-data)) err-invalid-status)

        (let (
                (escrow-amount (get amount escrow-data))
                (platform-fee (/ (* escrow-amount (var-get platform-fee-rate)) u10000))
                (carrier-payment (- escrow-amount platform-fee))
            )
            (if (> carrier-payment u0)
                (unwrap!
                    (as-contract (stx-transfer? carrier-payment tx-sender
                        (get carrier shipment)
                    ))
                    (err u999)
                )
                true
            )

            (map-set escrow-balances { shipment-id: shipment-id }
                (merge escrow-data {
                    released: true,
                    release-block: (some stacks-block-height),
                })
            )

            (ok true)
        )
    )
)

(define-read-only (get-shipments-by-sender (sender principal))
    (filter get-sender-shipments
        (list
            u1             u2             u3             u4             u5
            u6             u7             u8             u9             u10
            u11             u12             u13             u14             u15
            u16             u17             u18             u19
            u20
        ))
)

(define-read-only (get-shipments-by-receiver (receiver principal))
    (filter get-receiver-shipments
        (list
            u1             u2             u3             u4             u5
            u6             u7             u8             u9             u10
            u11             u12             u13             u14             u15
            u16             u17             u18             u19
            u20
        ))
)

(define-read-only (get-shipments-by-carrier (carrier principal))
    (filter get-carrier-shipments
        (list
            u1             u2             u3             u4             u5
            u6             u7             u8             u9             u10
            u11             u12             u13             u14             u15
            u16             u17             u18             u19
            u20
        ))
)

(define-private (get-sender-shipments (shipment-id uint))
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (is-eq (get sender shipment) tx-sender)
        false
    )
)

(define-private (get-receiver-shipments (shipment-id uint))
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (is-eq (get receiver shipment) tx-sender)
        false
    )
)

(define-private (get-carrier-shipments (shipment-id uint))
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (is-eq (get carrier shipment) tx-sender)
        false
    )
)

(define-read-only (get-shipment-timeline (shipment-id uint))
    (let ((update-count (default-to u0
            (get count
                (map-get? shipment-update-count { shipment-id: shipment-id })
            ))))
        (map get-timeline-update (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
    )
)

(define-private (get-timeline-update (update-id uint))
    (map-get? shipment-updates {
        shipment-id: u1,
        update-id: update-id,
    })
)

(define-read-only (get-delivery-estimate (shipment-id uint))
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (some (get estimated-delivery shipment))
        none
    )
)

(define-read-only (is-shipment-delivered (shipment-id uint))
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (is-eq (get status shipment) "delivered")
        false
    )
)

(define-read-only (is-shipment-delayed (shipment-id uint))
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (and
            (not (is-eq (get status shipment) "delivered"))
            (> stacks-block-height (get estimated-delivery shipment))
        )
        false
    )
)

(define-read-only (get-shipment-value (shipment-id uint))
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (some (get value shipment))
        none
    )
)

(define-read-only (get-total-shipments)
    (- (var-get next-shipment-id) u1)
)

(define-read-only (verify-tracking-hash
        (shipment-id uint)
        (provided-hash (string-ascii 64))
    )
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (is-eq (get tracking-hash shipment) provided-hash)
        false
    )
)

(define-public (update-estimated-delivery
        (shipment-id uint)
        (new-estimate uint)
    )
    (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get carrier shipment)) err-unauthorized)
        (asserts! (> new-estimate stacks-block-height) err-invalid-status)

        (map-set shipments { shipment-id: shipment-id }
            (merge shipment {
                estimated-delivery: new-estimate,
                updated-at: stacks-block-height,
            })
        )

        (add-shipment-update shipment-id (get status shipment) "update"
            "Estimated delivery time updated"
        )
    )
)

(define-public (cancel-shipment
        (shipment-id uint)
        (reason (string-ascii 200))
    )
    (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found)))
        (asserts!
            (or (is-eq tx-sender (get sender shipment)) (is-eq tx-sender (get carrier shipment)))
            err-unauthorized
        )
        (asserts! (not (is-eq (get status shipment) "delivered"))
            err-invalid-status
        )

        (map-set shipments { shipment-id: shipment-id }
            (merge shipment {
                status: "cancelled",
                updated-at: stacks-block-height,
            })
        )

        (add-shipment-update shipment-id "cancelled" "cancelled" reason)
    )
)

(define-read-only (get-active-shipments-count)
    (let ((total (get-total-shipments)))
        (fold count-active-shipments
            (list
                u1                 u2                 u3                 u4
                u5                 u6                 u7                 u8
                u9                 u10                 u11                 u12
                u13                 u14                 u15                 u16
                u17                 u18
                u19                 u20
            )
            u0
        )
    )
)

(define-private (count-active-shipments
        (shipment-id uint)
        (acc uint)
    )
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (if (and
                (not (is-eq (get status shipment) "delivered"))
                (not (is-eq (get status shipment) "cancelled"))
            )
            (+ acc u1)
            acc
        )
        acc
    )
)

(define-read-only (get-carrier-performance (carrier principal))
    (let (
            (total-shipments (fold count-carrier-shipments
                (list
                    u1                     u2                     u3
                    u4                     u5                     u6
                    u7                     u8                     u9
                    u10                     u11                     u12
                    u13                     u14                     u15
                    u16                     u17
                    u18                     u19                     u20
                )
                u0
            ))
            (delivered-on-time (fold count-on-time-deliveries
                (list
                    u1                     u2                     u3
                    u4                     u5                     u6
                    u7                     u8                     u9
                    u10                     u11                     u12
                    u13                     u14                     u15
                    u16                     u17
                    u18                     u19                     u20
                )
                u0
            ))
        )
        {
            total: total-shipments,
            on-time: delivered-on-time,
            performance: (if (> total-shipments u0)
                (/ (* delivered-on-time u100) total-shipments)
                u0
            ),
        }
    )
)

(define-private (count-carrier-shipments
        (shipment-id uint)
        (acc uint)
    )
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (if (is-eq (get carrier shipment) tx-sender)
            (+ acc u1)
            acc
        )
        acc
    )
)

(define-private (count-on-time-deliveries
        (shipment-id uint)
        (acc uint)
    )
    (match (map-get? shipments { shipment-id: shipment-id })
        shipment (if (and
                (is-eq (get carrier shipment) tx-sender)
                (is-eq (get status shipment) "delivered")
                (match (get actual-delivery shipment)
                    delivery-block (<= delivery-block (get estimated-delivery shipment))
                    false
                )
            )
            (+ acc u1)
            acc
        )
        acc
    )
)

(define-read-only (get-shipment-history (shipment-id uint))
    (let (
            (shipment (map-get? shipments { shipment-id: shipment-id }))
            (updates (get-shipment-timeline shipment-id))
        )
        {
            shipment: shipment,
            updates: updates,
        }
    )
)

(define-public (file-insurance-claim
        (shipment-id uint)
        (amount-claimed uint)
        (reason (string-ascii 200))
    )
    (let (
            (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id })
                err-not-found
            ))
            (policy (unwrap! (map-get? insurance-policies { shipment-id: shipment-id })
                err-not-found
            ))
            (claim-id (var-get next-claim-id))
            (existing-claim (map-get? shipment-claims { shipment-id: shipment-id }))
        )
        (asserts! (is-eq tx-sender (get policy-holder policy)) err-unauthorized)
        (asserts! (get active policy) err-invalid-status)
        (asserts! (<= amount-claimed (get coverage-amount policy))
            err-invalid-status
        )
        (asserts! (is-none (get claim-id existing-claim))
            err-claim-already-exists
        )
        (asserts! (not (is-eq (get status shipment) "delivered"))
            err-invalid-status
        )

        (map-set insurance-claims { claim-id: claim-id } {
            shipment-id: shipment-id,
            claimant: tx-sender,
            amount-claimed: amount-claimed,
            reason: reason,
            status: "pending",
            filed-at: stacks-block-height,
            resolved-at: none,
            approved-amount: u0,
        })

        (map-set shipment-claims { shipment-id: shipment-id } { claim-id: (some claim-id) })
        (var-set next-claim-id (+ claim-id u1))

        (ok claim-id)
    )
)

(define-public (process-insurance-claim
        (claim-id uint)
        (approved bool)
        (approved-amount uint)
    )
    (let (
            (claim (unwrap! (map-get? insurance-claims { claim-id: claim-id })
                err-claim-not-found
            ))
            (shipment-id (get shipment-id claim))
            (policy (unwrap! (map-get? insurance-policies { shipment-id: shipment-id })
                err-not-found
            ))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status claim) "pending") err-invalid-claim-status)
        (asserts! (<= approved-amount (get amount-claimed claim))
            err-invalid-status
        )

        (let ((new-status (if approved
                "approved"
                "rejected"
            )))
            (map-set insurance-claims { claim-id: claim-id }
                (merge claim {
                    status: new-status,
                    resolved-at: (some stacks-block-height),
                    approved-amount: approved-amount,
                })
            )

            (if (and approved (> approved-amount u0))
                (begin
                    (unwrap!
                        (as-contract (stx-transfer? approved-amount tx-sender
                            (get claimant claim)
                        ))
                        (err u999)
                    )
                    (map-set insurance-policies { shipment-id: shipment-id }
                        (merge policy { active: false })
                    )
                )
                true
            )

            (ok new-status)
        )
    )
)

(define-public (refund-escrow (shipment-id uint))
    (let (
            (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id })
                err-not-found
            ))
            (escrow-data (unwrap! (map-get? escrow-balances { shipment-id: shipment-id })
                err-not-found
            ))
        )
        (asserts!
            (or
                (is-eq tx-sender (get sender shipment))
                (is-eq tx-sender contract-owner)
            )
            err-unauthorized
        )
        (asserts! (not (get released escrow-data)) err-invalid-status)
        (asserts!
            (or
                (is-eq (get status shipment) "cancelled")
                (> stacks-block-height (+ (get estimated-delivery shipment) u144))
            )
            err-invalid-status
        )

        (let ((refund-amount (get amount escrow-data)))
            (unwrap!
                (as-contract (stx-transfer? refund-amount tx-sender (get sender shipment)))
                (err u999)
            )

            (map-set escrow-balances { shipment-id: shipment-id }
                (merge escrow-data {
                    released: true,
                    release-block: (some stacks-block-height),
                })
            )

            (ok refund-amount)
        )
    )
)

(define-read-only (get-escrow-status (shipment-id uint))
    (map-get? escrow-balances { shipment-id: shipment-id })
)

(define-read-only (get-insurance-policy (shipment-id uint))
    (map-get? insurance-policies { shipment-id: shipment-id })
)

(define-read-only (get-insurance-claim (claim-id uint))
    (map-get? insurance-claims { claim-id: claim-id })
)

(define-read-only (get-shipment-claim (shipment-id uint))
    (map-get? shipment-claims { shipment-id: shipment-id })
)

(define-read-only (calculate-insurance-premium (shipment-value uint))
    (/ (* shipment-value (var-get insurance-rate)) u10000)
)

(define-read-only (calculate-platform-fee (escrow-amount uint))
    (/ (* escrow-amount (var-get platform-fee-rate)) u10000)
)

(define-public (update-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate u1000) err-invalid-status)
        (var-set platform-fee-rate new-rate)
        (ok new-rate)
    )
)

(define-public (update-insurance-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate u2000) err-invalid-status)
        (var-set insurance-rate new-rate)
        (ok new-rate)
    )
)

(define-read-only (get-total-escrow-locked)
    (fold calculate-total-escrow
        (list
            u1             u2             u3             u4             u5
            u6             u7             u8             u9             u10
            u11             u12             u13             u14             u15
            u16             u17             u18             u19             u20
        )
        u0
    )
)

(define-private (calculate-total-escrow
        (shipment-id uint)
        (acc uint)
    )
    (match (map-get? escrow-balances { shipment-id: shipment-id })
        escrow-data (if (not (get released escrow-data))
            (+ acc (get amount escrow-data))
            acc
        )
        acc
    )
)

(define-public (submit-rating
        (shipment-id uint)
        (rated-user principal)
        (score uint)
    )
    (let (
            (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id })
                err-not-found
            ))
            (rating-id (var-get next-rating-id))
            (existing-rating (map-get? user-ratings {
                shipment-id: shipment-id,
                rater: tx-sender,
            }))
            (current-total (default-to u0
                (get total-score (map-get? rating-totals { user: rated-user }))
            ))
            (current-count (default-to u0
                (get count (map-get? rating-counts { user: rated-user }))
            ))
        )
        (asserts! (is-eq (get status shipment) "delivered") err-invalid-status)
        (asserts!
            (or (is-eq tx-sender (get sender shipment)) (is-eq tx-sender (get receiver shipment)))
            err-unauthorized
        )
        (asserts! (not (is-eq tx-sender rated-user)) err-invalid-rated-user)
        (asserts! (and (>= score u1) (<= score u5)) err-invalid-rating)
        (asserts! (is-none existing-rating) err-rating-already-exists)
        (asserts!
            (or (is-eq rated-user (get receiver shipment)) (is-eq rated-user (get carrier shipment)))
            err-invalid-rated-user
        )

        (map-set ratings { rating-id: rating-id } {
            shipment-id: shipment-id,
            rater: tx-sender,
            rated-user: rated-user,
            score: score,
            timestamp: stacks-block-height,
        })

        (map-set user-ratings {
            shipment-id: shipment-id,
            rater: tx-sender,
        } { rating-id: rating-id }
        )

        (map-set rating-totals { user: rated-user } { total-score: (+ current-total score) })

        (map-set rating-counts { user: rated-user } { count: (+ current-count u1) })

        (var-set next-rating-id (+ rating-id u1))

        (ok rating-id)
    )
)
