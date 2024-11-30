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

;; Book status types
(define-constant STATUS_AVAILABLE u1)
(define-constant STATUS_BORROWED u2)
(define-constant STATUS_INACTIVE u3)

;; Data Maps

(define-map user-books 
  principal 
  { book-count: uint, borrowed-count: uint })

(define-map deposits principal uint)
