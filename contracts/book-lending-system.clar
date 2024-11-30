;; Book Lending Smart Contract
;; This contract enables users to list, borrow, and return books, with a lending fee system. 
;; It enforces deposit requirements, limits on the number of books a user can list, 
;; and maintains book status (available, borrowed, inactive). 
;; Admins can adjust lending fees and the maximum lending period. 
;; Error handling ensures secure transactions and operations.

;; Data Variables
(define-data-var lending-fee uint u5) ;; 5% fee for lending
(define-data-var max-lending-period uint u30) ;; Maximum days for lending
(define-data-var deposit-requirement uint u1000000) ;; Required deposit in microSTX
(define-data-var max-books-per-user uint u10) ;; Maximum books a user can list
(define-data-var total-books uint u0) ;; Total books in the system

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-params (err u102))
(define-constant err-insufficient-deposit (err u103))
(define-constant err-book-unavailable (err u104))
(define-constant err-invalid-return (err u105))
(define-constant err-limit-exceeded (err u106))
(define-constant err-book-exists (err u107))
(define-constant err-not-owner (err u108))
(define-constant err-already-borrowed (err u109))
(define-constant err-insufficient-funds (err u110))
(define-constant err-invalid-title (err u111))
(define-constant err-invalid-author (err u112))
(define-constant err-invalid-book-id (err u113))

;; Book status types
(define-constant STATUS_AVAILABLE u1)
(define-constant STATUS_BORROWED u2)
(define-constant STATUS_INACTIVE u3)

;; Data Maps
(define-map books 
  { book-id: uint } 
  {
    owner: principal,
    title: (string-ascii 64),
    author: (string-ascii 64),
    status: uint,
    lending-price: uint,
    borrower: (optional principal),
    borrow-date: (optional uint)
  })

(define-map user-books 
  principal 
  { book-count: uint, borrowed-count: uint })

(define-map deposits principal uint)

;; Private Functions
(define-private (validate-string-input (input (string-ascii 64)))
  (and (not (is-eq input "")) 
       (<= (len input) u64)))

(define-private (validate-book-id (book-id uint))
  (and (>= book-id u0) 
       (< book-id (var-get total-books))))

(define-private (check-user-limits (user principal))
  (let ((user-data (default-to { book-count: u0, borrowed-count: u0 } 
                              (map-get? user-books user))))
    (ok (< (get book-count user-data) (var-get max-books-per-user)))))

(define-private (calculate-fee (amount uint))
  (ok (/ (* amount (var-get lending-fee)) u100)))

(define-private (update-book-count (user principal) (delta int))
  (let ((current-data (default-to { book-count: u0, borrowed-count: u0 } 
                                (map-get? user-books user))))
    (ok (map-set user-books 
                 user 
                 { book-count: (if (< delta 0)
                                  (- (get book-count current-data) (to-uint (- 0 delta)))
                                  (+ (get book-count current-data) (to-uint delta))),
                   borrowed-count: (get borrowed-count current-data) }))))

;; Public Functions
(define-public (list-book (title (string-ascii 64)) 
                         (author (string-ascii 64)) 
                         (lending-price uint))
  (begin
    ;; Validate inputs
    (asserts! (validate-string-input title) err-invalid-title)
    (asserts! (validate-string-input author) err-invalid-author)
    (asserts! (> lending-price u0) err-invalid-params)
    
    (let ((book-id (var-get total-books)))
      (asserts! (unwrap! (check-user-limits tx-sender) err-limit-exceeded) err-limit-exceeded)
      (unwrap! (update-book-count tx-sender 1) err-invalid-params)
      (var-set total-books (+ book-id u1))
      (ok (map-set books 
                   { book-id: book-id }
                   { owner: tx-sender,
                     title: title,
                     author: author,
                     status: STATUS_AVAILABLE,
                     lending-price: lending-price,
                     borrower: none,
                     borrow-date: none })))))

(define-public (borrow-book (book-id uint))
  (begin
    (asserts! (validate-book-id book-id) err-invalid-book-id)
    (let ((book (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable))
          (lending-fee-amount (unwrap! (calculate-fee (get lending-price book)) err-invalid-params))
          (total-cost (+ (get lending-price book) (var-get deposit-requirement))))
      (asserts! (is-eq (get status book) STATUS_AVAILABLE) err-book-unavailable)
      (asserts! (not (is-eq (get owner book) tx-sender)) err-unauthorized)
      (asserts! (>= (stx-get-balance tx-sender) total-cost) err-insufficient-funds)
      
      ;; Transfer lending fee to contract owner
      (unwrap! (stx-transfer? lending-fee-amount tx-sender contract-owner) err-insufficient-funds)
      ;; Transfer lending price to book owner
      (unwrap! (stx-transfer? (get lending-price book) tx-sender (get owner book)) err-insufficient-funds)
      ;; Store deposit
      (ok (map-set books 
                   { book-id: book-id }
                   (merge book { status: STATUS_BORROWED,
                               borrower: (some tx-sender),
                               borrow-date: (some block-height) }))))))

(define-public (return-book (book-id uint))
  (begin
    (asserts! (validate-book-id book-id) err-invalid-book-id)
    (let ((book (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable))
          (borrower (unwrap! (get borrower book) err-invalid-return)))
      (asserts! (is-eq borrower tx-sender) err-unauthorized)
      (asserts! (is-eq (get status book) STATUS_BORROWED) err-invalid-return)
      
      ;; Return deposit to borrower
      (unwrap! (stx-transfer? (var-get deposit-requirement) 
                              contract-owner 
                              tx-sender) err-insufficient-deposit)
      
      (map-delete deposits tx-sender)
      (ok (map-set books 
                   { book-id: book-id }
                   (merge book { status: STATUS_AVAILABLE,
                               borrower: none,
                               borrow-date: none }))))))

(define-public (remove-book (book-id uint))
  (begin
    (asserts! (validate-book-id book-id) err-invalid-book-id)
    (let ((book (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable)))
      (asserts! (is-eq (get owner book) tx-sender) err-not-owner)
      (asserts! (is-eq (get status book) STATUS_AVAILABLE) err-book-unavailable)
      (unwrap! (update-book-count tx-sender (- 0 1)) err-invalid-params)
      (ok (map-set books 
                   { book-id: book-id }
                   (merge book { status: STATUS_INACTIVE }))))))
