(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-shipment-exists (err u104))
(define-constant err-invalid-participant (err u105))

(define-data-var next-shipment-id uint u1)

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
    )
    (let (
            (shipment-id (var-get next-shipment-id))
            (current-block stacks-block-height)
        )
        (asserts! (is-authorized-carrier carrier) err-unauthorized)
        (asserts! (> estimated-delivery current-block) err-invalid-status)

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
        })

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
    (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get receiver shipment)) err-unauthorized)
        (asserts! (is-eq (get status shipment) "delivered") err-invalid-status)
        (ok true)
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
