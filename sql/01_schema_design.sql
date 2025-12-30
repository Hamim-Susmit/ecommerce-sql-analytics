-- =====================================================
-- OLIST E-COMMERCE DATABASE SCHEMA
-- Normalized Relational Design for Analytics
-- =====================================================

/*
BUSINESS CONTEXT:
Olist is a Brazilian e-commerce marketplace connecting small businesses to customers.
This schema supports analysis of:
- Customer purchasing behavior
- Product performance
- Seller performance
- Order fulfillment & logistics
- Customer satisfaction (reviews)

SCHEMA DESIGN PRINCIPLES:
1. Normalized to 3NF to eliminate redundancy
2. Clear fact/dimension separation
3. Optimized for analytical queries
4. Supports time-series and cohort analysis
*/

-- =====================================================
-- DIMENSION TABLES (Master Data)
-- =====================================================

-- Customers (Who is buying?)
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL,  -- Groups multiple customer_ids for same person
    customer_zip_code VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state CHAR(2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_unique ON customers(customer_unique_id);
CREATE INDEX idx_customers_location ON customers(customer_state, customer_city);

-- Products (What is being sold?)
CREATE TABLE products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category VARCHAR(100),
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

CREATE INDEX idx_products_category ON products(product_category);

-- Sellers (Who is selling?)
CREATE TABLE sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state CHAR(2)
);

CREATE INDEX idx_sellers_location ON sellers(seller_state, seller_city);

-- =====================================================
-- FACT TABLES (Transactional Data)
-- =====================================================

-- Orders (Core business transactions)
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Critical indexes for analytics queries
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_purchase_date ON orders(order_purchase_timestamp);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_orders_delivered_date ON orders(order_delivered_customer_date);

-- Order Items (Line-level detail - where revenue lives)
CREATE TABLE order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date TIMESTAMP,
    price DECIMAL(10,2) NOT NULL,
    freight_value DECIMAL(10,2) NOT NULL,
    
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
);

CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_order_items_seller ON order_items(seller_id);

-- Order Payments (Payment method & installments)
CREATE TABLE order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type VARCHAR(20) NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value DECIMAL(10,2) NOT NULL,
    
    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE INDEX idx_payments_type ON order_payments(payment_type);

-- Order Reviews (Customer satisfaction)
CREATE TABLE order_reviews (
    review_id VARCHAR(50) PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    review_score INTEGER NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title VARCHAR(100),
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE INDEX idx_reviews_order ON order_reviews(order_id);
CREATE INDEX idx_reviews_score ON order_reviews(review_score);

-- =====================================================
-- REFERENCE DATA
-- =====================================================

-- Product Category Translation (Portuguese to English)
CREATE TABLE product_category_translation (
    category_name_portuguese VARCHAR(100) PRIMARY KEY,
    category_name_english VARCHAR(100) NOT NULL
);

-- =====================================================
-- ANALYTICAL VIEWS (Pre-computed for Performance)
-- =====================================================

-- Complete Order View (Denormalized for analysis)
CREATE OR REPLACE VIEW vw_order_analytics AS
SELECT 
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    DATE_TRUNC('month', o.order_purchase_timestamp) as order_month,
    DATE_TRUNC('year', o.order_purchase_timestamp) as order_year,
    oi.product_id,
    p.product_category,
    oi.seller_id,
    s.seller_state,
    oi.price,
    oi.freight_value,
    (oi.price + oi.freight_value) as total_order_value,
    op.payment_type,
    op.payment_installments,
    op.payment_value,
    r.review_score,
    -- Calculate delivery performance
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) as delivery_days,
    EXTRACT(DAY FROM (o.order_estimated_delivery_date - o.order_delivered_customer_date)) as delivery_vs_estimate_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN order_payments op ON o.order_id = op.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered';

-- =====================================================
-- WHY THIS SCHEMA WORKS FOR ANALYTICS
-- =====================================================

/*
DESIGN DECISIONS:

1. STAR SCHEMA PATTERN
   - Central fact table (orders, order_items)
   - Surrounding dimensions (customers, products, sellers)
   - Enables fast JOIN operations for analysis

2. SEPARATE FACT TABLES
   - orders: One row per transaction
   - order_items: One row per product (handles multi-item orders)
   - order_payments: Handles split payments
   - Allows accurate revenue calculation at multiple grains

3. TEMPORAL TRACKING
   - Multiple timestamps capture order lifecycle
   - Enables cohort analysis, retention studies
   - Supports delivery performance metrics

4. INDEXES FOR PERFORMANCE
   - Customer, product, date indexes speed up GROUP BY queries
   - Status index enables fast filtering
   - Critical for 100k+ row datasets

5. ANALYTICAL VIEW
   - Pre-joins common analysis patterns
   - Simplifies complex queries
   - Acts as semantic layer for BI tools

6. DATA QUALITY CONSTRAINTS
   - Primary keys prevent duplicates
   - Foreign keys ensure referential integrity
   - CHECK constraints validate business rules
   - NOT NULL enforces complete data

SCALABILITY:
- This schema handles millions of orders efficiently
- Partitioning by order_month can optimize queries further
- Materialized views can cache expensive aggregations
*/