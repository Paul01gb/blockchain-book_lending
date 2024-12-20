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

;; Optimized function to calculate the lending fee
(define-private (optimized-calculate-fee (amount uint))
  (ok (/ (* amount (var-get lending-fee)) u100)))

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

;; Check if user has active books
(define-private (has-active-books (user principal))
  (begin
    ;; Returns true if the user has active books listed
    (let ((user-data (default-to { book-count: u0, borrowed-count: u0 } 
                                 (map-get? user-books user))))
      (ok (> (get book-count user-data) u0)))))

;; Validate that the lending price is within reasonable bounds
(define-private (validate-lending-price (price uint))
  (ok (and (> price u0) (<= price u1000000))))

;; Helper function to calculate late fee based on days overdue
(define-private (calculate-late-fee (days-overdue uint))
  (ok (* days-overdue u100)))

;; Check if the user is eligible to borrow more books
(define-private (check-borrowing-limits (user principal))
  (let ((user-data (default-to { book-count: u0, borrowed-count: u0 } 
                              (map-get? user-books user))))
    (ok (< (get borrowed-count user-data) u5))))

;; Fetch the current book owner
(define-private (get-book-owner (book-id uint))
  (let ((book (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable)))
    (ok (get owner book))))

;; Validate that the borrow date is within the allowed lending period
(define-private (validate-borrow-date (borrow-date uint))
  (ok (<= (- block-height borrow-date) (var-get max-lending-period))))

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

;; Update lending price for a book
(define-public (update-lending-price (book-id uint) (new-price uint))
  (begin
    ;; Updates the lending price for a book if the sender is the owner
    (asserts! (validate-book-id book-id) err-invalid-book-id)
    (asserts! (> new-price u0) err-invalid-params)
    (let ((book (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable)))
      (asserts! (is-eq (get owner book) tx-sender) err-not-owner)
      (ok (map-set books { book-id: book-id } (merge book { lending-price: new-price }))))))

;; Allows the book owner to update the title
(define-public (change-book-title (book-id uint) (new-title (string-ascii 64)))
  (begin
    (asserts! (validate-string-input new-title) err-invalid-title)
    (asserts! (validate-book-id book-id) err-invalid-book-id)
    (let ((book (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable)))
      (asserts! (is-eq (get owner book) tx-sender) err-not-owner)
      (ok (map-set books 
                   { book-id: book-id } 
                   (merge book { title: new-title })))))) 

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

;; Admin Functions
(define-public (set-lending-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (<= new-fee u100) err-invalid-params)
    (ok (var-set lending-fee new-fee))))

;; Admin function to set the maximum number of books a user can list
(define-public (set-max-books-per-user (max-books uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (> max-books u0) err-invalid-params)
    (ok (var-set max-books-per-user max-books))))

(define-public (set-max-lending-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (> new-period u0) err-invalid-params)
    (ok (var-set max-lending-period new-period))))

;; Admin function to adjust deposit requirement
(define-public (set-deposit-requirement (new-requirement uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (> new-requirement u0) err-invalid-params)
    (ok (var-set deposit-requirement new-requirement))))

;; Allow user to donate a book without listing fee
(define-public (donate-book (title (string-ascii 64)) (author (string-ascii 64)))
  (begin
    (asserts! (validate-string-input title) err-invalid-title)
    (asserts! (validate-string-input author) err-invalid-author)
    (let ((book-id (var-get total-books)))
      (var-set total-books (+ book-id u1))
      (ok (map-set books { book-id: book-id }
                   { owner: contract-owner,
                     title: title,
                     author: author,
                     status: STATUS_AVAILABLE,
                     lending-price: u0,
                     borrower: none,
                     borrow-date: none })))))

;; Read-only Functions
(define-read-only (get-book-details (book-id uint))
  (begin
    (asserts! (validate-book-id book-id) err-invalid-book-id)
    (ok (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable))))

(define-read-only (get-user-books (user principal))
  (ok (default-to { book-count: u0, borrowed-count: u0 } 
                 (map-get? user-books user))))

(define-read-only (get-lending-fee)
  (ok (var-get lending-fee)))

(define-read-only (get-max-lending-period)
  (ok (var-get max-lending-period)))

(define-read-only (get-deposit-requirement)
  (ok (var-get deposit-requirement)))

(define-read-only (get-user-deposit (user principal))
  (ok (default-to u0 (map-get? deposits user))))

(define-read-only (get-total-books)
  (ok (var-get total-books)))

;; Check if a book is borrowed
(define-read-only (is-book-borrowed (book-id uint))
  (begin
    ;; Returns true if the book is borrowed
    (asserts! (validate-book-id book-id) err-invalid-book-id)
    (let ((book (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable)))
      (ok (is-eq (get status book) STATUS_BORROWED)))))
 
;; Check the status of a book
(define-read-only (check-book-status (book-id uint))
  (ok (get status (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable))))

;; Function to check if a book can be borrowed
(define-read-only (is-book-borrowable (book-id uint))
  (begin
    (asserts! (validate-book-id book-id) err-invalid-book-id)
    (let ((book (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable)))
      (ok (is-eq (get status book) STATUS_AVAILABLE)))))

;; Test function to verify the borrower details of a book
(define-read-only (get-borrower-details (book-id uint))
  (begin
    (asserts! (validate-book-id book-id) err-invalid-book-id)
    (ok (get borrower (unwrap! (map-get? books { book-id: book-id }) err-book-unavailable)))))
