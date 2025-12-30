-- =====================================================
-- DATA QUALITY VALIDATION QUERIES
-- Run after loading data to ensure integrity
-- =====================================================

/*
PURPOSE:
These queries validate data quality and identify issues that could
compromise analysis accuracy. Run in sequence and document findings.

BEST PRACTICE:
Always validate data before analysis. Bad data = bad insights.
*/

-- =====================================================
-- 1. ROW COUNTS & BASIC STATS
-- =====================================================

SELECT 'customers' as table_name, COUNT(*) as row_count FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
ORDER BY row_count DESC;

-- =====================================================
-- 2. DUPLICATE DETECTION
-- =====================================================

-- Check for duplicate customer IDs
SELECT 
    'Duplicate Customers' as check_name,
    COUNT(*) - COUNT(DISTINCT customer_id) as duplicate_count
FROM customers;

-- Check for duplicate order IDs
SELECT 
    'Duplicate Orders' as check_name,
    COUNT(*) - COUNT(DISTINCT order_id) as duplicate_count
FROM orders;

-- Identify duplicate order items (should be unique by order_id + order_item_id)
SELECT 
    order_id,
    order_item_id,
    COUNT(*) as occurrence_count
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- =====================================================
-- 3. NULL VALUE ANALYSIS
-- =====================================================

-- Critical fields that should never be NULL
SELECT 
    'Orders Missing Customer' as issue,
    COUNT(*) as count
FROM orders
WHERE customer_id IS NULL

UNION ALL

SELECT 
    'Orders Missing Purchase Timestamp',
    COUNT(*)
FROM orders
WHERE order_purchase_timestamp IS NULL

UNION ALL

SELECT 
    'Order Items Missing Price',
    COUNT(*)
FROM order_items
WHERE price IS NULL

UNION ALL

SELECT 
    'Order Items Missing Product',
    COUNT(*)
FROM order_items
WHERE product_id IS NULL;

-- Optional fields - measure completeness
SELECT 
    'Orders with Delivery Date' as metric,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL) as has_value,
    COUNT(*) as total,
    ROUND(100.0 * COUNT(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL) / COUNT(*), 2) as pct_complete
FROM orders

UNION ALL

SELECT 
    'Orders with Reviews',
    COUNT(DISTINCT order_id),
    (SELECT COUNT(*) FROM orders),
    ROUND(100.0 * COUNT(DISTINCT order_id) / (SELECT COUNT(*) FROM orders), 2)
FROM order_reviews;

-- =====================================================
-- 4. REFERENTIAL INTEGRITY
-- =====================================================

-- Orders referencing non-existent customers
SELECT 
    'Orders with Invalid Customer ID' as issue,
    COUNT(*) as count
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items referencing non-existent orders
SELECT 
    'Order Items with Invalid Order ID' as issue,
    COUNT(*) as count
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items referencing non-existent products
SELECT 
    'Order Items with Invalid Product ID' as issue,
    COUNT(*) as count
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- =====================================================
-- 5. DATE LOGIC VALIDATION
-- =====================================================

-- Orders with impossible dates (delivered before purchased)
SELECT 
    'Orders Delivered Before Purchase' as issue,
    COUNT(*) as count
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- Orders with approved date before purchase
SELECT 
    'Orders Approved Before Purchase' as issue,
    COUNT(*) as count
FROM orders
WHERE order_approved_at < order_purchase_timestamp;

-- Check date ranges for anomalies
SELECT 
    MIN(order_purchase_timestamp) as earliest_order,
    MAX(order_purchase_timestamp) as latest_order,
    MAX(order_purchase_timestamp) - MIN(order_purchase_timestamp) as date_range
FROM orders;

-- =====================================================
-- 6. BUSINESS RULE VALIDATION
-- =====================================================

-- Orders with negative or zero prices
SELECT 
    'Order Items with Invalid Price' as issue,
    COUNT(*) as count
FROM order_items
WHERE price <= 0;

-- Orders with negative or zero freight
SELECT 
    'Order Items with Invalid Freight' as issue,
    COUNT(*) as count
FROM order_items
WHERE freight_value < 0;

-- Payment value should match order value (within tolerance)
WITH order_totals AS (
    SELECT 
        oi.order_id,
        SUM(oi.price + oi.freight_value) as order_total,
        op.payment_value
    FROM order_items oi
    LEFT JOIN order_payments op ON oi.order_id = op.order_id
    GROUP BY oi.order_id, op.payment_value
)
SELECT 
    'Orders with Payment Mismatch' as issue,
    COUNT(*) as count
FROM order_totals
WHERE ABS(order_total - payment_value) > 0.01;  -- Allow 1 cent rounding difference

-- Review scores outside valid range (should be 1-5)
SELECT 
    'Invalid Review Scores' as issue,
    COUNT(*) as count
FROM order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;

-- =====================================================
-- 7. STATISTICAL OUTLIERS
-- =====================================================

-- Extreme order values (potential data errors)
WITH price_stats AS (
    SELECT 
        AVG(price) as avg_price,
        STDDEV(price) as stddev_price,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY price) as p99_price
    FROM order_items
)
SELECT 
    'Extreme High Prices (>3 StdDev)' as metric,
    COUNT(*) as count,
    MAX(price) as max_value
FROM order_items, price_stats
WHERE price > (avg_price + 3 * stddev_price);

-- Orders with excessive items (potential errors)
SELECT 
    order_id,
    COUNT(*) as item_count,
    SUM(price) as total_value
FROM order_items
GROUP BY order_id
HAVING COUNT(*) > 20  -- Flag orders with >20 items
ORDER BY item_count DESC;

-- =====================================================
-- 8. COMPLETENESS BY TIME PERIOD
-- =====================================================

-- Check for gaps in order dates
SELECT 
    DATE_TRUNC('month', order_purchase_timestamp) as order_month,
    COUNT(*) as order_count
FROM orders
GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY order_month;

-- =====================================================
-- 9. CATEGORY & STATUS DISTRIBUTION
-- =====================================================

-- Order status distribution (identify invalid statuses)
SELECT 
    order_status,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct
FROM orders
GROUP BY order_status
ORDER BY count DESC;

-- Top product categories (check for NULL or 'unknown')
SELECT 
    COALESCE(product_category, 'MISSING') as category,
    COUNT(*) as product_count
FROM products
GROUP BY product_category
ORDER BY product_count DESC
LIMIT 10;

-- =====================================================
-- 10. COMPREHENSIVE DATA QUALITY SCORECARD
-- =====================================================

WITH quality_metrics AS (
    SELECT 
        'Total Orders' as metric,
        COUNT(*)::text as value,
        'green' as status
    FROM orders
    
    UNION ALL
    
    SELECT 
        'Orders with Null Customer',
        COUNT(*)::text,
        CASE WHEN COUNT(*) = 0 THEN 'green' ELSE 'red' END
    FROM orders
    WHERE customer_id IS NULL
    
    UNION ALL
    
    SELECT 
        'Duplicate Orders',
        (COUNT(*) - COUNT(DISTINCT order_id))::text,
        CASE WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'green' ELSE 'red' END
    FROM orders
    
    UNION ALL
    
    SELECT 
        'Orders with Delivery Date',
        ROUND(100.0 * COUNT(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL) / COUNT(*), 1)::text || '%',
        CASE WHEN COUNT(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL) > 0.8 * COUNT(*) 
             THEN 'green' ELSE 'yellow' END
    FROM orders
    
    UNION ALL
    
    SELECT 
        'Negative Prices',
        COUNT(*)::text,
        CASE WHEN COUNT(*) = 0 THEN 'green' ELSE 'red' END
    FROM order_items
    WHERE price <= 0
    
    UNION ALL
    
    SELECT 
        'Orphaned Order Items',
        COUNT(*)::text,
        CASE WHEN COUNT(*) = 0 THEN 'green' ELSE 'red' END
    FROM order_items oi
    LEFT JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_id IS NULL
)
SELECT 
    metric,
    value,
    status,
    CASE 
        WHEN status = 'green' THEN '✓ PASS'
        WHEN status = 'yellow' THEN '⚠ WARNING'
        ELSE '✗ FAIL'
    END as result
FROM quality_metrics
ORDER BY 
    CASE status 
        WHEN 'red' THEN 1 
        WHEN 'yellow' THEN 2 
        ELSE 3 
    END,
    metric;

/*
INTERPRETATION GUIDE:

GREEN (✓ PASS):
- Data is clean and ready for analysis
- No action needed

YELLOW (⚠ WARNING):
- Data is usable but has minor issues
- Document assumptions in analysis
- Consider excluding incomplete records

RED (✗ FAIL):
- Critical data quality issue
- Must be fixed before analysis
- Contact data source owner

NEXT STEPS:
1. Document all RED and YELLOW findings
2. Decide on handling strategies (exclude, impute, flag)
3. Create cleaned dataset for analysis
4. Re-run validation on cleaned data
*/