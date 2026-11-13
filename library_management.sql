-- Library Management Database
-- DBMS: MySQL 8.0+
-- Run this script in MySQL Workbench or phpMyAdmin.

CREATE DATABASE IF NOT EXISTS library_management;
USE library_management;

-- Reset tables so the script can be rerun safely.
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS books;
DROP TABLE IF EXISTS users;

CREATE TABLE books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    isbn VARCHAR(20) NOT NULL UNIQUE,
    title VARCHAR(200) NOT NULL,
    author VARCHAR(150) NOT NULL,
    publisher VARCHAR(150),
    publication_year YEAR,
    total_copies INT NOT NULL DEFAULT 1,
    available_copies INT NOT NULL DEFAULT 1,
    CONSTRAINT chk_book_copies CHECK (
        total_copies >= 0 AND available_copies >= 0
        AND available_copies <= total_copies
    )
);

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20),
    user_type ENUM('Student', 'Faculty', 'Staff') NOT NULL DEFAULT 'Student',
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    user_id INT NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE NULL,
    status ENUM('Issued', 'Returned', 'Overdue') NOT NULL DEFAULT 'Issued',
    CONSTRAINT fk_transaction_book FOREIGN KEY (book_id)
        REFERENCES books(book_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_transaction_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_due_date CHECK (due_date >= issue_date),
    CONSTRAINT chk_return_date CHECK (return_date IS NULL OR return_date >= issue_date)
);

-- Sample records
INSERT INTO books (isbn, title, author, publisher, publication_year, total_copies, available_copies)
VALUES
('9780132350884', 'Introduction to Database Systems', 'A. Author', 'Academic Press', 2022, 5, 5),
('9781492057611', 'Learning SQL', 'B. Writer', 'Tech Books', 2021, 3, 3),
('9780132350885', 'Clean Code', 'Robert C. Martin', 'Prentice Hall', 2008, 2, 2);

INSERT INTO users (full_name, email, phone, user_type)
VALUES
('Arun Kumar', 'arun@example.com', '9876543210', 'Student'),
('Priya S', 'priya@example.com', '9876501234', 'Faculty');

-- ISSUE A BOOK
-- Use a transaction so stock and transaction records stay consistent.
START TRANSACTION;
SET @book_id = 1;
SET @user_id = 1;
SET @issue_date = CURRENT_DATE();
SET @due_date = DATE_ADD(@issue_date, INTERVAL 14 DAY);

UPDATE books
SET available_copies = available_copies - 1
WHERE book_id = @book_id AND available_copies > 0;

-- Insert only if the stock update succeeded.
SET @issued = ROW_COUNT();
INSERT INTO transactions (book_id, user_id, issue_date, due_date, status)
SELECT @book_id, @user_id, @issue_date, @due_date, 'Issued'
WHERE @issued = 1;
COMMIT;

-- RETURN A BOOK (replace transaction ID with the transaction to return)
SET @return_transaction_id = 1;
START TRANSACTION;
UPDATE transactions
SET return_date = CURRENT_DATE(), status = 'Returned'
WHERE transaction_id = @return_transaction_id
  AND status = 'Issued'
  AND return_date IS NULL;

SET @returned = ROW_COUNT();
UPDATE books b
JOIN transactions t ON t.book_id = b.book_id
SET b.available_copies = b.available_copies + 1
WHERE t.transaction_id = @return_transaction_id
  AND @returned = 1;
COMMIT;

-- TRACKING QUERIES

-- 1. List all books and their current availability.
SELECT book_id, title, author, total_copies, available_copies
FROM books
ORDER BY title;

-- 2. List all currently issued books with borrower and due date.
SELECT t.transaction_id, b.title, u.full_name, t.issue_date, t.due_date,
       CASE WHEN t.due_date < CURRENT_DATE() THEN 'Overdue' ELSE 'On time' END AS loan_status
FROM transactions t
JOIN books b ON b.book_id = t.book_id
JOIN users u ON u.user_id = t.user_id
WHERE t.status = 'Issued' AND t.return_date IS NULL
ORDER BY t.due_date;

-- 3. View complete transaction history.
SELECT t.transaction_id, b.title, u.full_name, t.issue_date,
       t.due_date, t.return_date, t.status
FROM transactions t
JOIN books b ON b.book_id = t.book_id
JOIN users u ON u.user_id = t.user_id
ORDER BY t.transaction_id DESC;

-- 4. Find all books borrowed by a particular user (change user_id as needed).
SET @search_user_id = 1;
SELECT b.title, t.issue_date, t.due_date, t.return_date, t.status
FROM transactions t
JOIN books b ON b.book_id = t.book_id
WHERE t.user_id = @search_user_id
ORDER BY t.issue_date DESC;

-- 5. Find overdue books.
SELECT t.transaction_id, b.title, u.full_name, u.email, t.due_date,
       DATEDIFF(CURRENT_DATE(), t.due_date) AS days_overdue
FROM transactions t
JOIN books b ON b.book_id = t.book_id
JOIN users u ON u.user_id = t.user_id
WHERE t.status = 'Issued' AND t.return_date IS NULL
  AND t.due_date < CURRENT_DATE();

-- 6. Count books currently borrowed by each user.
SELECT u.user_id, u.full_name, COUNT(t.transaction_id) AS books_currently_issued
FROM users u
LEFT JOIN transactions t
  ON t.user_id = u.user_id AND t.status = 'Issued' AND t.return_date IS NULL
GROUP BY u.user_id, u.full_name
ORDER BY u.full_name;

-- 7. Search books by title or author.
SELECT book_id, title, author, available_copies
FROM books
WHERE title LIKE '%SQL%' OR author LIKE '%SQL%';
