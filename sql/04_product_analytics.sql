-- =====================================================
-- PRODUCT PERFORMANCE ANALYTICS
-- Understanding what sells and why
-- =====================================================

/*
WHY PRODUCT ANALYTICS MATTERS:
- Inventory optimization (what to stock)
- Marketing focus (what to promote)
- Pricing strategy (identify premium products)
- Category expansion (where to grow)
- Product development (what customers want)
*/

-- =====================================================
-- 1. TOP PRODUCTS BY REVENUE
-- =====================================================

-- Overall best sellers
SELECT 
    p.product_category,
    COUNT(DISTINCT oi.product_id) as unique_products,
    COUNT(DISTINCT oi.order_id) as total_orders,
    SUM(oi.price + oi.freight_value) as total_revenue,
    ROUND(AVG(oi.price + oi.freight_value)::numeric, 2) as avg_order_value,
    ROUND(
        100.0 * SUM(oi.price + oi.freight_value) / 
        SUM(SUM(oi.price + oi.freight_value)) OVER ()
    , 2) as pct_of_total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
    AND p.product_category IS NOT NULL
GROUP BY p.product_category
ORDER BY total_revenue DESC
LIMIT 20;

/*
BUSINESS INSIGHT:
- Top 3 categories often generate 40-50% of revenue
- Focus marketing and inventory on these categories
- Identify underperforming categories for investigation or discontinuation
*/

-- =====================================================
-- 2. PRODUCT PERFORMANCE TRENDS
-- =====================================================

-- Track category growth over time
WITH monthly_category_sales AS (
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp) as order_month,
        p.product_category,
        COUNT(DISTINCT oi.order_id) as orders,
        SUM(oi.price + oi.freight_value) as revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND p.product_category IS NOT NULL
    GROUP BY 
        DATE_TRUNC('month', o.order_purchase_timestamp),
        p.product_category
)
SELECT 
    order_month,
    product_category,
    orders,
    revenue,
    LAG(revenue) OVER (
        PARTITION BY product_category 
        ORDER BY order_month
    ) as prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (
            PARTITION BY product_category 
            ORDER BY order_month
        )) / NULLIF(LAG(revenue) OVER (
            PARTITION BY product_category 
            ORDER BY order_month
        ), 0)
    , 2) as mom_growth_pct
FROM monthly_category_sales
WHERE order_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY product_category, order_month;

/*
WHAT TO LOOK FOR:
- Consistent growth = healthy category
- Declining growth = market saturation or competition
- Seasonality patterns (e.g., gifts spike in December)
- New category launches and their trajectory
*/

-- =====================================================
-- 3. PRODUCT PROFITABILITY MATRIX
-- =====================================================

-- Classify products by volume and value
WITH product_metrics AS (
    SELECT 
        p.product_category,
        COUNT(DISTINCT oi.order_id) as order_volume,
        AVG(oi.price) as avg_price,
        SUM(oi.price + oi.freight_value) as total_revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND p.product_category IS NOT NULL
    GROUP BY p.product_category
),
quartiles AS (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_volume) as median_volume,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_price) as median_price
    FROM product_metrics
)
SELECT 
    pm.product_category,
    pm.order_volume,
    ROUND(pm.avg_price::numeric, 2) as avg_price,
    ROUND(pm.total_revenue::numeric, 2) as total_revenue,
    CASE 
        WHEN pm.order_volume > q.median_volume AND pm.avg_price > q.median_price 
            THEN '⭐ Stars (High Volume, High Price)'
        WHEN pm.order_volume > q.median_volume AND pm.avg_price <= q.median_price 
            THEN '🔄 Cash Cows (High Volume, Low Price)'
        WHEN pm.order_volume <= q.median_volume AND pm.avg_price > q.median_price 
            THEN '💎 Premium (Low Volume, High Price)'
        ELSE '❓ Question Marks (Low Volume, Low Price)'
    END as product_quadrant
FROM product_metrics pm
CROSS JOIN quartiles q
ORDER BY pm.total_revenue DESC;

/*
STRATEGY BY QUADRANT:

⭐ STARS: Invest heavily, maximize inventory, feature in marketing
🔄 CASH COWS: Maintain, optimize operations, use for customer acquisition
💎 PREMIUM: Selective marketing, position as luxury, protect margins
❓ QUESTION MARKS: Evaluate for discontinuation or repositioning
*/

-- =====================================================
-- 4. CROSS-SELL ANALYSIS
-- =====================================================

-- What products are frequently bought together?
WITH product_pairs AS (
    SELECT 
        oi1.product_id as product_a,
        oi2.product_id as product_b,
        COUNT(DISTINCT oi1.order_id) as co_purchase_count
    FROM order_items oi1
    JOIN order_items oi2 
        ON oi1.order_id = oi2.order_id 
        AND oi1.product_id < oi2.product_id  -- Avoid duplicates
    JOIN orders o ON oi1.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi1.product_id, oi2.product_id
    HAVING COUNT(DISTINCT oi1.order_id) >= 10  -- Minimum threshold
)
SELECT 
    p1.product_category as category_a,
    p2.product_category as category_b,
    COUNT(*) as product_pair_count,
    SUM(pp.co_purchase_count) as total_co_purchases,
    ROUND(AVG(pp.co_purchase_count)::numeric, 1) as avg_co_purchases
FROM product_pairs pp
JOIN products p1 ON pp.product_a = p1.product_id
JOIN products p2 ON pp.product_b = p2.product_id
WHERE p1.product_category IS NOT NULL 
    AND p2.product_category IS NOT NULL
GROUP BY p1.product_category, p2.product_category
ORDER BY total_co_purchases DESC
LIMIT 20;

/*
CROSS-SELL OPPORTUNITIES:
- Product bundling strategies
- "Frequently bought together" recommendations
- Marketing campaign combinations
- Store layout optimization
*/

-- =====================================================
-- 5. PRODUCT VELOCITY & TURNOVER
-- =====================================================

-- How quickly do products sell?
WITH product_first_last AS (
    SELECT 
        p.product_category,
        MIN(o.order_purchase_timestamp) as first_sale,
        MAX(o.order_purchase_timestamp) as last_sale,
        COUNT(DISTINCT oi.order_id) as total_orders,
        COUNT(DISTINCT oi.product_id) as unique_products
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND p.product_category IS NOT NULL
    GROUP BY p.product_category
)
SELECT 
    product_category,
    total_orders,
    unique_products,
    ROUND(
        total_orders::numeric / 
        GREATEST(EXTRACT(DAY FROM (last_sale - first_sale)), 1)
    , 2) as avg_orders_per_day,
    ROUND(
        total_orders::numeric / unique_products
    , 2) as avg_orders_per_product,
    EXTRACT(DAY FROM (last_sale - first_sale)) as days_on_market
FROM product_first_last
WHERE EXTRACT(DAY FROM (last_sale - first_sale)) >= 30  -- At least 30 days
ORDER BY avg_orders_per_day DESC;

/*
INVENTORY INSIGHTS:
- High orders/day = fast movers, keep in stock
- Low orders/day = slow movers, reduce inventory
- Orders per product = how well each SKU performs
*/

-- =====================================================
-- 6. PRICE SENSITIVITY ANALYSIS
-- =====================================================

-- Analyze impact of price on sales volume
WITH price_buckets AS (
    SELECT 
        p.product_category,
        CASE 
            WHEN oi.price < 50 THEN '< $50'
            WHEN oi.price < 100 THEN '$50-100'
            WHEN oi.price < 200 THEN '$100-200'
            WHEN oi.price < 500 THEN '$200-500'
            ELSE '$500+'
        END as price_bucket,
        COUNT(DISTINCT oi.order_id) as orders,
        SUM(oi.price + oi.freight_value) as revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND p.product_category IS NOT NULL
    GROUP BY 
        p.product_category,
        CASE 
            WHEN oi.price < 50 THEN '< $50'
            WHEN oi.price < 100 THEN '$50-100'
            WHEN oi.price < 200 THEN '$100-200'
            WHEN oi.price < 500 THEN '$200-500'
            ELSE '$500+'
        END
)
SELECT 
    product_category,
    price_bucket,
    orders,
    ROUND(revenue::numeric, 2) as revenue,
    ROUND(100.0 * orders / SUM(orders) OVER (PARTITION BY product_category), 2) as pct_of_category_orders,
    ROUND(100.0 * revenue / SUM(revenue) OVER (PARTITION BY product_category), 2) as pct_of_category_revenue
FROM price_buckets
ORDER BY product_category, MIN(revenue) DESC;

/*
PRICING STRATEGY:
- Most orders in low price bucket? Consider premium line
- Most revenue in high price bucket? Invest in quality
- Balanced distribution? Multiple price points working
*/

-- =====================================================
-- 7. SEASONAL PRODUCT PATTERNS
-- =====================================================

-- Identify seasonal products for planning
SELECT 
    p.product_category,
    EXTRACT(MONTH FROM o.order_purchase_timestamp) as month,
    TO_CHAR(DATE_TRUNC('month', o.order_purchase_timestamp), 'Month') as month_name,
    COUNT(DISTINCT oi.order_id) as orders,
    ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as revenue,
    ROUND(
        100.0 * COUNT(DISTINCT oi.order_id) / 
        SUM(COUNT(DISTINCT oi.order_id)) OVER (PARTITION BY p.product_category)
    , 2) as pct_of_annual_orders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
    AND p.product_category IS NOT NULL
GROUP BY 
    p.product_category,
    EXTRACT(MONTH FROM o.order_purchase_timestamp),
    DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY p.product_category, month;

/*
SEASONAL PLANNING:
- Stock up before peak months
- Clear inventory during slow periods
- Adjust marketing calendar
- Plan promotions around natural peaks
*/

-- =====================================================
-- 8. PRODUCT REVIEW SENTIMENT ANALYSIS
-- =====================================================

-- Link product performance to customer satisfaction
SELECT 
    p.product_category,
    COUNT(DISTINCT r.review_id) as total_reviews,
    ROUND(AVG(r.review_score)::numeric, 2) as avg_review_score,
    COUNT(*) FILTER (WHERE r.review_score >= 4) as positive_reviews,
    COUNT(*) FILTER (WHERE r.review_score <= 2) as negative_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE r.review_score >= 4) / 
        COUNT(*)
    , 2) as positive_review_pct,
    COUNT(DISTINCT oi.order_id) as total_orders,
    ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as total_revenue
FROM order_reviews r
JOIN orders o ON r.order_id = o.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
    AND p.product_category IS NOT NULL
GROUP BY p.product_category
HAVING COUNT(DISTINCT r.review_id) >= 50
ORDER BY avg_review_score DESC;

/*
QUALITY INSIGHTS:
- Low review scores = quality issues, investigate immediately
- High scores = marketing opportunity, feature in campaigns
- Review volume = customer engagement indicator
- Negative reviews = opportunity for improvement
*/

-- =====================================================
-- 9. NEW PRODUCT PERFORMANCE TRACKING
-- =====================================================

-- Monitor recently launched products
WITH product_launch AS (
    SELECT 
        p.product_id,
        p.product_category,
        MIN(o.order_purchase_timestamp) as launch_date,
        EXTRACT(DAY FROM (CURRENT_DATE - MIN(o.order_purchase_timestamp))) as days_since_launch
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY p.product_id, p.product_category
)
SELECT 
    pl.product_category,
    COUNT(DISTINCT pl.product_id) as new_products,
    ROUND(AVG(pl.days_since_launch)::numeric, 0) as avg_days_since_launch,
    COUNT(DISTINCT oi.order_id) as total_orders,
    ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as total_revenue,
    ROUND(
        COUNT(DISTINCT oi.order_id)::numeric / 
        AVG(pl.days_since_launch)
    , 2) as avg_orders_per_day
FROM product_launch pl
JOIN order_items oi ON pl.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE pl.days_since_launch <= 90  -- New = last 90 days
    AND o.order_status = 'delivered'
GROUP BY pl.product_category
ORDER BY total_revenue DESC;

/*
NEW PRODUCT SUCCESS METRICS:
- Orders per day = immediate traction
- Compare to category average for benchmarking
- Fast movers = expand inventory
- Slow movers = reconsider pricing or marketing
*/

-- =====================================================
-- 10. PRODUCT PORTFOLIO HEALTH SCORECARD
-- =====================================================

-- Comprehensive category performance evaluation
WITH category_metrics AS (
    SELECT 
        p.product_category,
        COUNT(DISTINCT oi.product_id) as product_count,
        COUNT(DISTINCT oi.order_id) as order_count,
        ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as revenue,
        ROUND(AVG(oi.price)::numeric, 2) as avg_price,
        ROUND(AVG(r.review_score)::numeric, 2) as avg_review,
        -- Calculate growth
        ROUND(
            100.0 * (
                SUM(CASE WHEN o.order_purchase_timestamp >= CURRENT_DATE - INTERVAL '3 months' 
                    THEN oi.price + oi.freight_value END) -
                SUM(CASE WHEN o.order_purchase_timestamp >= CURRENT_DATE - INTERVAL '6 months' 
                         AND o.order_purchase_timestamp < CURRENT_DATE - INTERVAL '3 months'
                    THEN oi.price + oi.freight_value END)
            ) / NULLIF(SUM(CASE WHEN o.order_purchase_timestamp >= CURRENT_DATE - INTERVAL '6 months' 
                         AND o.order_purchase_timestamp < CURRENT_DATE - INTERVAL '3 months'
                    THEN oi.price + oi.freight_value END), 0)
        , 2) as quarterly_growth_pct
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
        AND p.product_category IS NOT NULL
    GROUP BY p.product_category
)
SELECT 
    product_category,
    product_count,
    order_count,
    revenue,
    avg_price,
    avg_review,
    quarterly_growth_pct,
    -- Health score calculation
    CASE 
        WHEN revenue > 100000 AND avg_review >= 4.0 AND quarterly_growth_pct > 5 
            THEN '🟢 Excellent'
        WHEN revenue > 50000 AND avg_review >= 3.5 
            THEN '🟡 Good'
        WHEN quarterly_growth_pct < -10 OR avg_review < 3.0 
            THEN '🔴 Needs Attention'
        ELSE '🟡 Moderate'
    END as health_status,
    -- Strategic recommendation
    CASE 
        WHEN revenue > 100000 AND quarterly_growth_pct > 10 
            THEN 'Invest & Scale'
        WHEN revenue > 50000 AND quarterly_growth_pct BETWEEN -5 AND 5 
            THEN 'Maintain & Optimize'
        WHEN quarterly_growth_pct < -10 
            THEN 'Turnaround or Exit'
        ELSE 'Monitor'
    END as recommendation
FROM category_metrics
ORDER BY revenue DESC;

/*
=================================================
PRODUCT STRATEGY SUMMARY
=================================================

INVESTMENT PRIORITIES:
1. Stars (High Volume + High Price): Maximize
2. Cash Cows: Optimize efficiency
3. Premium: Selective growth
4. Question Marks: Evaluate ROI

IMMEDIATE ACTIONS:
- Double down on categories with >10% growth
- Investigate categories with declining reviews
- Bundle frequently co-purchased items
- Plan inventory for seasonal peaks
- Sunset products with <3.0 reviews

QUARTERLY REVIEW:
- Track new product performance
- Monitor cross-sell effectiveness
- Adjust pricing based on elasticity
- Reallocate marketing budget to winners

DASHBOARD METRICS:
- Revenue by category (monthly trend)
- Top 10 products (by revenue)
- Review score distribution
- Inventory turnover rate
- Price sensitivity analysis
- Seasonal index by category
*/