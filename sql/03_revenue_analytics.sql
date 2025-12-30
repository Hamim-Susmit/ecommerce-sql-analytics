-- =====================================================
-- REVENUE & GROWTH ANALYTICS
-- Core business metrics for executive reporting
-- =====================================================

/*
BUSINESS CONTEXT:
Revenue is the lifeblood of e-commerce. These queries answer:
- Are we growing or declining?
- What drives our revenue?
- Where should we invest?
*/

-- =====================================================
-- 1. TOTAL REVENUE OVERVIEW
-- =====================================================

-- High-level business summary
SELECT 
    COUNT(DISTINCT o.order_id) as total_orders,
    COUNT(DISTINCT o.customer_id) as total_customers,
    COUNT(DISTINCT oi.product_id) as products_sold,
    COUNT(DISTINCT oi.seller_id) as active_sellers,
    ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as total_revenue,
    ROUND(AVG(oi.price + oi.freight_value)::numeric, 2) as avg_order_value,
    ROUND(SUM(oi.price + oi.freight_value) / COUNT(DISTINCT o.customer_id)::numeric, 2) as revenue_per_customer,
    MIN(o.order_purchase_timestamp)::date as first_order_date,
    MAX(o.order_purchase_timestamp)::date as last_order_date
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

/*
WHAT THESE METRICS MEAN:
- Total Orders: Volume of transactions (operational health)
- Total Revenue: Top-line business performance
- AOV: Efficiency metric - higher is better
- Revenue per Customer: Customer value - target for improvement
*/

-- =====================================================
-- 2. MONTHLY REVENUE TRENDS
-- =====================================================

-- Month-over-month revenue analysis
WITH monthly_revenue AS (
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp) as order_month,
        COUNT(DISTINCT o.order_id) as orders,
        COUNT(DISTINCT o.customer_id) as customers,
        ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT 
    order_month,
    orders,
    customers,
    revenue,
    ROUND(revenue / orders::numeric, 2) as avg_order_value,
    ROUND(revenue / customers::numeric, 2) as revenue_per_customer,
    -- Month-over-month growth
    LAG(revenue) OVER (ORDER BY order_month) as prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month)) / 
        NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0)
    , 2) as mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;

/*
HOW TO READ THIS:
- Look for consistent growth (positive MoM%)
- Identify seasonality patterns
- Flag months with negative growth for investigation
- Benchmark: Healthy e-commerce grows 5-10% MoM
*/

-- =====================================================
-- 3. QUARTERLY REVENUE PERFORMANCE
-- =====================================================

-- Quarterly aggregation for board reporting
SELECT 
    DATE_TRUNC('quarter', o.order_purchase_timestamp) as quarter,
    COUNT(DISTINCT o.order_id) as total_orders,
    ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as total_revenue,
    ROUND(AVG(oi.price + oi.freight_value)::numeric, 2) as avg_order_value,
    -- Quarter-over-quarter growth
    ROUND(
        100.0 * (SUM(oi.price + oi.freight_value) - 
                 LAG(SUM(oi.price + oi.freight_value)) OVER (ORDER BY DATE_TRUNC('quarter', o.order_purchase_timestamp))) / 
        NULLIF(LAG(SUM(oi.price + oi.freight_value)) OVER (ORDER BY DATE_TRUNC('quarter', o.order_purchase_timestamp)), 0)
    , 2) as qoq_growth_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('quarter', o.order_purchase_timestamp)
ORDER BY quarter;

-- =====================================================
-- 4. REVENUE BY DAY OF WEEK
-- =====================================================

-- Identify peak shopping days
SELECT 
    TO_CHAR(o.order_purchase_timestamp, 'Day') as day_of_week,
    EXTRACT(DOW FROM o.order_purchase_timestamp) as day_number,
    COUNT(DISTINCT o.order_id) as total_orders,
    ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as total_revenue,
    ROUND(AVG(oi.price + oi.freight_value)::numeric, 2) as avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY 
    TO_CHAR(o.order_purchase_timestamp, 'Day'),
    EXTRACT(DOW FROM o.order_purchase_timestamp)
ORDER BY day_number;

/*
BUSINESS APPLICATION:
- Schedule promotions on peak days
- Staff customer service accordingly
- Time email campaigns for high-traffic days
*/

-- =====================================================
-- 5. REVENUE BY HOUR OF DAY
-- =====================================================

-- Optimize campaign timing
SELECT 
    EXTRACT(HOUR FROM o.order_purchase_timestamp) as hour_of_day,
    COUNT(DISTINCT o.order_id) as total_orders,
    ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as total_revenue,
    ROUND(100.0 * COUNT(DISTINCT o.order_id) / SUM(COUNT(DISTINCT o.order_id)) OVER (), 2) as pct_of_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY EXTRACT(HOUR FROM o.order_purchase_timestamp)
ORDER BY hour_of_day;

-- =====================================================
-- 6. AVERAGE ORDER VALUE TRENDS
-- =====================================================

-- Track if customers are spending more per transaction
WITH monthly_aov AS (
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp) as order_month,
        AVG(oi.price + oi.freight_value) as avg_order_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT 
    order_month,
    ROUND(avg_order_value::numeric, 2) as aov,
    LAG(avg_order_value) OVER (ORDER BY order_month) as prev_month_aov,
    ROUND(
        100.0 * (avg_order_value - LAG(avg_order_value) OVER (ORDER BY order_month)) / 
        NULLIF(LAG(avg_order_value) OVER (ORDER BY order_month), 0)
    , 2) as aov_growth_pct
FROM monthly_aov
ORDER BY order_month;

/*
WHY AOV MATTERS:
- Increasing AOV = more efficient revenue generation
- Cheaper than acquiring new customers
- Strategies: bundling, upsells, free shipping thresholds
*/

-- =====================================================
-- 7. REVENUE DISTRIBUTION ANALYSIS
-- =====================================================

-- Understand order value distribution
SELECT 
    CASE 
        WHEN order_value < 50 THEN '< $50'
        WHEN order_value < 100 THEN '$50-100'
        WHEN order_value < 200 THEN '$100-200'
        WHEN order_value < 500 THEN '$200-500'
        ELSE '$500+'
    END as order_value_bucket,
    COUNT(*) as order_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct_of_orders,
    ROUND(SUM(order_value)::numeric, 2) as total_revenue,
    ROUND(100.0 * SUM(order_value) / SUM(SUM(order_value)) OVER (), 2) as pct_of_revenue
FROM (
    SELECT 
        o.order_id,
        SUM(oi.price + oi.freight_value) as order_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
) order_values
GROUP BY 
    CASE 
        WHEN order_value < 50 THEN '< $50'
        WHEN order_value < 100 THEN '$50-100'
        WHEN order_value < 200 THEN '$100-200'
        WHEN order_value < 500 THEN '$200-500'
        ELSE '$500+'
    END
ORDER BY 
    MIN(order_value);

/*
INSIGHT QUESTIONS:
- Are most orders in the low-value bucket?
- Do high-value orders drive disproportionate revenue?
- Should we focus on moving customers to higher buckets?
*/

-- =====================================================
-- 8. CUMULATIVE REVENUE CURVE
-- =====================================================

-- Show revenue accumulation over time
SELECT 
    order_date::date,
    daily_revenue,
    SUM(daily_revenue) OVER (ORDER BY order_date) as cumulative_revenue,
    ROUND(
        100.0 * SUM(daily_revenue) OVER (ORDER BY order_date) / 
        SUM(daily_revenue) OVER ()
    , 2) as pct_of_total_revenue
FROM (
    SELECT 
        DATE_TRUNC('day', o.order_purchase_timestamp) as order_date,
        SUM(oi.price + oi.freight_value) as daily_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('day', o.order_purchase_timestamp)
) daily
ORDER BY order_date;

-- =====================================================
-- 9. YEAR-OVER-YEAR COMPARISON
-- =====================================================

-- Compare same months across years
SELECT 
    TO_CHAR(order_month, 'Month') as month_name,
    EXTRACT(YEAR FROM order_month) as year,
    ROUND(revenue::numeric, 2) as revenue,
    LAG(revenue, 12) OVER (ORDER BY order_month) as same_month_last_year,
    ROUND(
        100.0 * (revenue - LAG(revenue, 12) OVER (ORDER BY order_month)) / 
        NULLIF(LAG(revenue, 12) OVER (ORDER BY order_month), 0)
    , 2) as yoy_growth_pct
FROM (
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp) as order_month,
        SUM(oi.price + oi.freight_value) as revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
) monthly
ORDER BY order_month;

-- =====================================================
-- 10. REVENUE VELOCITY METRICS
-- =====================================================

-- How fast is revenue coming in?
WITH daily_stats AS (
    SELECT 
        DATE_TRUNC('day', o.order_purchase_timestamp)::date as order_date,
        COUNT(DISTINCT o.order_id) as orders,
        SUM(oi.price + oi.freight_value) as revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('day', o.order_purchase_timestamp)::date
)
SELECT 
    ROUND(AVG(revenue)::numeric, 2) as avg_daily_revenue,
    ROUND(STDDEV(revenue)::numeric, 2) as stddev_daily_revenue,
    ROUND(MIN(revenue)::numeric, 2) as min_daily_revenue,
    ROUND(MAX(revenue)::numeric, 2) as max_daily_revenue,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue)::numeric, 2) as median_daily_revenue,
    -- Coefficient of variation (volatility measure)
    ROUND(STDDEV(revenue) / NULLIF(AVG(revenue), 0) * 100, 2) as cv_pct
FROM daily_stats;

/*
INTERPRETING VELOCITY:
- High StdDev = Unpredictable revenue (risky)
- Low StdDev = Stable revenue (predictable)
- CV > 50% = High volatility, needs investigation
- Median vs Mean = Shows impact of outlier days
*/

/*
=================================================
KEY TAKEAWAYS FOR BUSINESS STAKEHOLDERS
=================================================

1. GROWTH HEALTH
   - Track MoM and YoY growth consistently
   - Investigate months with negative growth
   - Set targets: 5-10% MoM for scaling phase

2. AOV OPTIMIZATION
   - Rising AOV = more value per transaction
   - Test: Free shipping thresholds, bundles, upsells
   - Monitor AOV by customer segment

3. REVENUE PATTERNS
   - Day/hour analysis informs marketing timing
   - Seasonality planning for inventory/staffing
   - Revenue distribution shows customer segments

4. FORECASTING
   - Use historical trends for budget planning
   - Account for seasonality in projections
   - Monitor daily velocity for early warnings

NEXT STEPS:
- Share monthly revenue trends with leadership
- Set AOV improvement goal (e.g., +5% this quarter)
- Plan promotions around peak shopping patterns
*/