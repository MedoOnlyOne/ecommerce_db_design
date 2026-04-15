CREATE TABLE numbers (n INT PRIMARY KEY);

SET SESSION cte_max_recursion_depth = 100000;

INSERT INTO numbers (n)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 100000
)
SELECT n FROM seq;

SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;
SET AUTOCOMMIT = 0;

-- 🧹 Clean and Reset
TRUNCATE TABLE ORDER_DETAILS;
TRUNCATE TABLE ORDERS;
TRUNCATE TABLE PRODUCTS;
TRUNCATE TABLE CUSTOMERS;
TRUNCATE TABLE CATEGORY;

-- 📦 Categories (Adding weights for realistic distribution)
INSERT INTO CATEGORY (CATEGORY_NAME) VALUES
                                         ('Electronics'), ('Mobile'), ('Laptops'), ('Fashion'), ('Home'),
                                         ('Sports'), ('Books'), ('Beauty'), ('Toys'), ('Groceries');

-- 👤 Customers (100K)
INSERT INTO CUSTOMERS (FIRST_NAME, LAST_NAME, EMAIL, PASSWORD)
SELECT
    ELT(FLOOR(1 + RAND()*10), 'Ahmed','Mohamed','Sara','Fatma','John','Emily','David','Linda','Youssef','Maria'),
    ELT(FLOOR(1 + RAND()*10), 'Ali','Hassan','Ibrahim','Smith','Clark','Omar','Jones','Taylor','Khan','Garcia'),
    CONCAT('user', n, '_', FLOOR(RAND()*9999), '@mail.com'),
    'hash_placeholder'
FROM numbers WHERE n <= 100000;

-- 📦 Products (100K) - Realistic Price Distribution (Logarithmic-style)
-- Most items are cheap, few are expensive
INSERT INTO PRODUCTS (CATEGORY_ID, NAME, DESCRIPTION, PRICE, STOCK_QUANTITY)
SELECT
    FLOOR(1 + (POWER(RAND(), 2) * 10)), -- Skews category selection
    CONCAT('Product-', n),
    'High quality product description',
    ROUND(10 + (POWER(RAND(), 3) * 2000), 2), -- More products at lower price points
    FLOOR(RAND() * 200)
FROM numbers WHERE n <= 100000;

-- 🧾 1. Orders (100K)
-- We use 1.00 instead of 0 to satisfy the CHECK(TOTAL_AMOUNT > 0)
INSERT INTO ORDERS (CUSTOMER_ID, ORDER_DATE, TOTAL_AMOUNT)
SELECT
    FLOOR(1 + RAND() * 100000),
    NOW() - INTERVAL (POWER(RAND(), 2) * 365) DAY,
    1.00
FROM numbers WHERE n <= 100000;

-- 🛒 2. Order Details (1–5 items per order)
-- 2.1. Create a temporary mapping of how many items each order has
-- This avoids the heavy JOIN calculation
CREATE TEMPORARY TABLE order_manifest AS
SELECT
    ORDER_ID,
    -- Calculate cart size once per order using a realistic distribution
    FLOOR(1 + (POWER(RAND(), 2) * 5)) as cart_size
FROM ORDERS;

-- 2.2. Insert into ORDER_DETAILS using a clean join
-- We join against a static set of numbers (1-5)
INSERT INTO ORDER_DETAILS (ORDER_ID, PRODUCT_ID, QUANTITY, UNIT_PRICE)
SELECT
    m.ORDER_ID,
    FLOOR(1 + RAND() * 100000), -- Fast random product selection
    FLOOR(1 + RAND() * 10),      -- Random quantity
    1.00                         -- Placeholder
FROM order_manifest m
         JOIN (
    SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5
) row_multiplier ON row_multiplier.n <= m.cart_size;

-- 2.3. Cleanup
DROP TEMPORARY TABLE order_manifest;

-- 🔗 3. Sync Prices from Products
-- Faster than doing it during the initial INSERT
UPDATE ORDER_DETAILS od
    JOIN PRODUCTS p ON od.PRODUCT_ID = p.PRODUCT_ID
    SET od.UNIT_PRICE = p.PRICE;

-- 💰 4. Final Totals Fix
-- This calculates the actual sum and overrides the 1.00 placeholder
UPDATE ORDERS o
    JOIN (
    SELECT ORDER_ID, SUM(QUANTITY * UNIT_PRICE) AS total
    FROM ORDER_DETAILS
    GROUP BY ORDER_ID
    ) x ON o.ORDER_ID = x.ORDER_ID
    SET o.TOTAL_AMOUNT = x.total;

COMMIT;
SET FOREIGN_KEY_CHECKS = 1;
SET UNIQUE_CHECKS = 1;
SET AUTOCOMMIT = 1;