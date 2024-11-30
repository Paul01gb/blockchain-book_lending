# Book Lending Smart Contract

This is a smart contract built with Clarity for managing a decentralized book lending system. The contract allows users to list books for lending, borrow books, return books, and manage deposits. It also includes administrative features for setting lending fees and maximum lending periods.

## Features

- **List Books**: Users can list their books for lending with title, author, and price.
- **Borrow Books**: Users can borrow books by paying a lending fee and deposit.
- **Return Books**: Borrowers can return books and receive their deposit back.
- **Remove Books**: Book owners can remove their books from the system.
- **Administrative Controls**: The contract owner can set the lending fee and maximum lending period.

## Contract Variables

### Data Variables

- `lending-fee`: 5% fee for lending.
- `max-lending-period`: Maximum days for lending (default: 30 days).
- `deposit-requirement`: Required deposit for lending (default: 1,000,000 microSTX).
- `max-books-per-user`: Maximum books a user can list (default: 10).
- `total-books`: Tracks the total number of books listed in the system.

### Constants

- `contract-owner`: Address of the contract owner.
- `err-unauthorized`: Error when a non-owner tries to perform an action restricted to the contract owner.
- `err-invalid-params`: Error for invalid parameters.
- `err-insufficient-deposit`: Error when a borrower does not have enough deposit.
- `err-book-unavailable`: Error when a book is not available for borrowing.
- `err-invalid-return`: Error when trying to return a book that was not borrowed.
- `err-limit-exceeded`: Error when a user tries to list more than the maximum number of books.
- `err-book-exists`: Error when trying to list a book that already exists.
- `err-not-owner`: Error when the user is not the owner of the book.
- `err-already-borrowed`: Error when the book is already borrowed.
- `err-insufficient-funds`: Error when the user has insufficient funds for the transaction.
- `err-invalid-title`: Error when the book title is invalid.
- `err-invalid-author`: Error when the book author is invalid.
- `err-invalid-book-id`: Error when the book ID is invalid.

### Book Status Types

- `STATUS_AVAILABLE`: Book is available for lending.
- `STATUS_BORROWED`: Book is currently borrowed.
- `STATUS_INACTIVE`: Book is inactive and cannot be borrowed.

## Functions

### Public Functions

#### `list-book`
- **Parameters**: 
  - `title` (string): The title of the book.
  - `author` (string): The author of the book.
  - `lending-price` (uint): The price to borrow the book.
- **Description**: Allows users to list a book for lending. The user must provide a valid title, author, and a positive lending price.

#### `borrow-book`
- **Parameters**: 
  - `book-id` (uint): The ID of the book to borrow.
- **Description**: Allows users to borrow a book by paying the lending price and a deposit. The borrower cannot be the owner of the book.

#### `return-book`
- **Parameters**: 
  - `book-id` (uint): The ID of the book to return.
- **Description**: Allows users to return a borrowed book and receive their deposit back.

#### `remove-book`
- **Parameters**: 
  - `book-id` (uint): The ID of the book to remove.
- **Description**: Allows the book owner to remove their book from the system if it is available for lending.

### Admin Functions

#### `set-lending-fee`
- **Parameters**: 
  - `new-fee` (uint): The new lending fee (in percentage).
- **Description**: Allows the contract owner to set a new lending fee.

#### `set-max-lending-period`
- **Parameters**: 
  - `new-period` (uint): The new maximum lending period in days.
- **Description**: Allows the contract owner to set a new maximum lending period.

### Read-only Functions

#### `get-book-details`
- **Parameters**: 
  - `book-id` (uint): The ID of the book.
- **Description**: Retrieves details of a specific book by its ID.

#### `get-user-books`
- **Parameters**: 
  - `user` (principal): The address of the user.
- **Description**: Retrieves the number of books listed and borrowed by a specific user.

#### `get-lending-fee`
- **Description**: Retrieves the current lending fee.

#### `get-max-lending-period`
- **Description**: Retrieves the current maximum lending period.

#### `get-deposit-requirement`
- **Description**: Retrieves the required deposit for lending.

#### `get-user-deposit`
- **Parameters**: 
  - `user` (principal): The address of the user.
- **Description**: Retrieves the deposit balance of a specific user.

#### `get-total-books`
- **Description**: Retrieves the total number of books in the system.

## How to Interact with the Contract

### Listing a Book
To list a book, call the `list-book` function with the book's title, author, and lending price. Ensure that you don't exceed the maximum number of books allowed per user.

Example:
```clarity
(list-book "Book Title" "Author Name" 500)
```

### Borrowing a Book
To borrow a book, use the `borrow-book` function and provide the book's ID. Make sure you have sufficient funds to cover the lending price and the required deposit.

Example:
```clarity
(borrow-book 1)
```

### Returning a Book
When returning a borrowed book, call the `return-book` function with the book's ID. Your deposit will be refunded after the book is successfully returned.

Example:
```clarity
(return-book 1)
```

### Removing a Book
If you are the owner of a book and it is available for lending, you can remove it from the system using the `remove-book` function.

Example:
```clarity
(remove-book 1)
```

## Contract Limitations

- Each user can list a maximum of 10 books.
- The contract enforces a lending fee and requires a deposit for each lending transaction.
- The contract owner has administrative rights to adjust the lending fee and the maximum lending period.

## License

This contract is licensed under the MIT License.

## Security Considerations

- Always verify the correctness of the book ID and user balances before making any transactions.
- Ensure that you do not share your private key with anyone to protect your account from unauthorized actions.

## Acknowledgments

This contract was built using the Clarity language and is designed to facilitate decentralized book lending in a secure and transparent manner.
```
