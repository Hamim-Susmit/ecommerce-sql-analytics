-- =====================================================
-- COHORT & RETENTION ANALYSIS
-- Understanding customer behavior over time
-- =====================================================

/*
WHAT IS COHORT ANALYSIS?
- Groups customers by their first purchase month (cohort)
- Tracks how each cohort behaves over time
- Reveals if retention is improving or declining

WHY IT MATTERS:
- Early warning system for business health
- Shows impact of product/service changes
- Proves if growth is sustainable
- Essential for LTV calculations
*/

-- =====================================================
-- 1. BASIC COHORT SETUP
-- =====================================================

-- Identify each customer's cohort (first purchase month)
CREATE OR REPLACE VIEW vw_customer_cohorts AS
WITH customer_first_purchase AS (
    SELECT 
        c.customer_unique_id,
        MIN(DATE_TRUNC('month', o.order_purchase_timestamp)) as cohort_month,
        MIN(o.order_purchase_timestamp) as first_purchase_timestamp
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT 
    c.customer_unique_id,
    c.customer_id,
    o.order_id,
    o.order_purchase_timestamp,
    DATE_TRUNC('month', o.order_purchase_timestamp) as order_month,
    cfp.cohort_month,
    cfp.first_purchase_timestamp,
    -- Calculate months since first purchase
    EXTRACT(YEAR FROM AGE(o.order_purchase_timestamp, cfp.first_purchase_timestamp)) * 12 +
    EXTRACT(MONTH FROM AGE(o.order_purchase_timestamp, cfp.first_purchase_timestamp)) as months_since_first_purchase,
    oi.price + oi.freight_value as order_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customer_first_purchase cfp ON c.customer_unique_id = cfp.customer_unique_id
WHERE o.order_status = 'delivered';

-- =====================================================
-- 2. COHORT SIZE & ACQUISITION TRENDS
-- =====================================================

-- How many customers acquired each month?
SELECT 
    cohort_month,
    COUNT(DISTINCT customer_unique_id) as cohort_size,
    ROUND(SUM(order_value)::numeric, 2) as first_month_revenue,
    ROUND(AVG(order_value)::numeric, 2) as avg_first_order_value
FROM vw_customer_cohorts
WHERE months_since_first_purchase = 0
GROUP BY cohort_month
ORDER BY cohort_month;

/*
WHAT TO LOOK FOR:
- Growing cohort sizes = healthy acquisition
- Shrinking cohorts = marketing problems
- Rising first order value = better customer quality
*/

-- =====================================================
-- 3. MONTHLY RETENTION TABLE
-- =====================================================

-- Core retention analysis: What % of each cohort returns each month?
WITH cohort_activity AS (
    SELECT 
        cohort_month,
        months_since_first_purchase,
        COUNT(DISTINCT customer_unique_id) as active_customers
    FROM vw_customer_cohorts
    GROUP BY cohort_month, months_since_first_purchase
),
cohort_sizes AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_unique_id) as cohort_size
    FROM vw_customer_cohorts
    WHERE months_since_first_purchase = 0
    GROUP BY cohort_month
)
SELECT 
    ca.cohort_month,
    cs.cohort_size,
    ca.months_since_first_purchase as month_number,
    ca.active_customers,
    ROUND(100.0 * ca.active_customers / cs.cohort_size, 2) as retention_pct
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
ORDER BY ca.cohort_month, ca.months_since_first_purchase;

/*
HOW TO READ RETENTION:
- Month 0: Always 100% (first purchase)
- Month 1: Critical - shows if customers return
- Month 3-6: Shows stickiness
- Month 12+: Shows long-term loyalty

BENCHMARKS:
- Month 1: 20-30% is healthy
- Month 6: 15-20% is good
- Improving trends = product/service is working
*/

-- =====================================================
-- 4. RETENTION CURVE (PIVOT FORMAT FOR VISUALIZATION)
-- =====================================================

-- Easier to visualize retention patterns
SELECT 
    cohort_month,
    cohort_size,
    MAX(CASE WHEN month_number = 0 THEN retention_pct END) as month_0,
    MAX(CASE WHEN month_number = 1 THEN retention_pct END) as month_1,
    MAX(CASE WHEN month_number = 2 THEN retention_pct END) as month_2,
    MAX(CASE WHEN month_number = 3 THEN retention_pct END) as month_3,
    MAX(CASE WHEN month_number = 6 THEN retention_pct END) as month_6,
    MAX(CASE WHEN month_number = 12 THEN retention_pct END) as month_12
FROM (
    SELECT 
        ca.cohort_month,
        cs.cohort_size,
        ca.months_since_first_purchase as month_number,
        ROUND(100.0 * ca.active_customers / cs.cohort_size, 2) as retention_pct
    FROM (
        SELECT 
            cohort_month,
            months_since_first_purchase,
            COUNT(DISTINCT customer_unique_id) as active_customers
        FROM vw_customer_cohorts
        GROUP BY cohort_month, months_since_first_purchase
    ) ca
    JOIN (
        SELECT 
            cohort_month,
            COUNT(DISTINCT customer_unique_id) as cohort_size
        FROM vw_customer_cohorts
        WHERE months_since_first_purchase = 0
        GROUP BY cohort_month
    ) cs ON ca.cohort_month = cs.cohort_month
) retention_data
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;

-- =====================================================
-- 5. REPEAT PURCHASE RATE
-- =====================================================

-- What % of customers make a 2nd purchase?
WITH customer_purchase_counts AS (
    SELECT 
        customer_unique_id,
        cohort_month,
        COUNT(DISTINCT order_id) as total_purchases
    FROM vw_customer_cohorts
    GROUP BY customer_unique_id, cohort_month
)
SELECT 
    cohort_month,
    COUNT(*) as total_customers,
    COUNT(*) FILTER (WHERE total_purchases >= 2) as customers_with_repeat,
    ROUND(100.0 * COUNT(*) FILTER (WHERE total_purchases >= 2) / COUNT(*), 2) as repeat_purchase_rate_pct,
    COUNT(*) FILTER (WHERE total_purchases >= 3) as customers_with_3plus,
    ROUND(100.0 * COUNT(*) FILTER (WHERE total_purchases >= 3) / COUNT(*), 2) as triple_purchase_rate_pct
FROM customer_purchase_counts
GROUP BY cohort_month
ORDER BY cohort_month;

/*
CRITICAL INSIGHT:
The jump from 1st to 2nd purchase is the HARDEST.
Getting a customer to buy twice dramatically increases LTV.

FOCUS HERE:
- Post-purchase email sequences
- Loyalty incentives
- Product recommendations
*/

-- =====================================================
-- 6. COHORT REVENUE ANALYSIS
-- =====================================================

-- How much revenue does each cohort generate over time?
SELECT 
    cohort_month,
    months_since_first_purchase as month_number,
    COUNT(DISTINCT customer_unique_id) as active_customers,
    ROUND(SUM(order_value)::numeric, 2) as monthly_revenue,
    ROUND(AVG(order_value)::numeric, 2) as avg_order_value,
    -- Cumulative revenue from cohort
    ROUND(
        SUM(SUM(order_value)) OVER (
            PARTITION BY cohort_month 
            ORDER BY months_since_first_purchase
        )::numeric
    , 2) as cumulative_cohort_revenue
FROM vw_customer_cohorts
GROUP BY cohort_month, months_since_first_purchase
ORDER BY cohort_month, months_since_first_purchase;

/*
USE THIS FOR:
- LTV projections
- Marketing budget allocation
- Cohort profitability analysis
*/

-- =====================================================
-- 7. TIME TO SECOND PURCHASE
-- =====================================================

-- How long does it take customers to return?
WITH customer_purchases AS (
    SELECT 
        customer_unique_id,
        order_purchase_timestamp,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) as purchase_number
    FROM vw_customer_cohorts
),
second_purchase_timing AS (
    SELECT 
        p1.customer_unique_id,
        p1.order_purchase_timestamp as first_purchase,
        p2.order_purchase_timestamp as second_purchase,
        EXTRACT(DAY FROM (p2.order_purchase_timestamp - p1.order_purchase_timestamp)) as days_to_second_purchase
    FROM customer_purchases p1
    JOIN customer_purchases p2 
        ON p1.customer_unique_id = p2.customer_unique_id
        AND p1.purchase_number = 1
        AND p2.purchase_number = 2
)
SELECT 
    CASE 
        WHEN days_to_second_purchase <= 30 THEN '0-30 days'
        WHEN days_to_second_purchase <= 60 THEN '31-60 days'
        WHEN days_to_second_purchase <= 90 THEN '61-90 days'
        WHEN days_to_second_purchase <= 180 THEN '91-180 days'
        ELSE '180+ days'
    END as time_bucket,
    COUNT(*) as customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct_of_repeat_customers,
    ROUND(AVG(days_to_second_purchase)::numeric, 1) as avg_days
FROM second_purchase_timing
GROUP BY 
    CASE 
        WHEN days_to_second_purchase <= 30 THEN '0-30 days'
        WHEN days_to_second_purchase <= 60 THEN '31-60 days'
        WHEN days_to_second_purchase <= 90 THEN '61-90 days'
        WHEN days_to_second_purchase <= 180 THEN '91-180 days'
        ELSE '180+ days'
    END
ORDER BY MIN(days_to_second_purchase);

/*
MARKETING APPLICATION:
- Most customers return in 60-90 days?
- Send re-engagement email at day 45
- Offer incentive before they forget about you
*/

-- =====================================================
-- 8. COHORT COMPARISON: EARLY VS RECENT
-- =====================================================

-- Are newer cohorts better or worse than older ones?
WITH cohort_metrics AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_unique_id) as cohort_size,
        COUNT(DISTINCT customer_unique_id) FILTER (
            WHERE months_since_first_purchase >= 1
        ) as returned_month_1,
        COUNT(DISTINCT customer_unique_id) FILTER (
            WHERE months_since_first_purchase >= 3
        ) as returned_month_3,
        ROUND(AVG(order_value)::numeric, 2) as avg_order_value,
        ROUND(
            SUM(order_value) / COUNT(DISTINCT customer_unique_id)::numeric
        , 2) as revenue_per_customer
    FROM vw_customer_cohorts
    GROUP BY cohort_month
)
SELECT 
    cohort_month,
    cohort_size,
    returned_month_1,
    ROUND(100.0 * returned_month_1 / NULLIF(cohort_size, 0), 2) as month_1_retention_pct,
    returned_month_3,
    ROUND(100.0 * returned_month_3 / NULLIF(cohort_size, 0), 2) as month_3_retention_pct,
    avg_order_value,
    revenue_per_customer
FROM cohort_metrics
ORDER BY cohort_month;

/*
TREND ANALYSIS:
- Rising retention = improving product/experience
- Falling retention = quality issues, need investigation
- Compare to business changes (new features, pricing, etc.)
*/

-- =====================================================
-- 9. COHORT MATURITY & LTV PROJECTION
-- =====================================================

-- Estimate lifetime value based on mature cohorts
WITH mature_cohorts AS (
    SELECT 
        cohort_month,
        customer_unique_id,
        SUM(order_value) as customer_ltv,
        COUNT(DISTINCT order_id) as total_orders,
        MAX(months_since_first_purchase) as months_active
    FROM vw_customer_cohorts
    WHERE cohort_month <= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')  -- At least 12 months old
    GROUP BY cohort_month, customer_unique_id
)
SELECT 
    'Mature Cohort Average' as metric,
    ROUND(AVG(customer_ltv)::numeric, 2) as avg_ltv,
    ROUND(AVG(total_orders)::numeric, 1) as avg_orders,
    ROUND(AVG(months_active)::numeric, 1) as avg_months_active,
    COUNT(*) as customer_count
FROM mature_cohorts

UNION ALL

SELECT 
    'Top 25% of Customers',
    ROUND(AVG(customer_ltv)::numeric, 2),
    ROUND(AVG(total_orders)::numeric, 1),
    ROUND(AVG(months_active)::numeric, 1),
    COUNT(*)
FROM (
    SELECT 
        customer_ltv,
        total_orders,
        months_active,
        NTILE(4) OVER (ORDER BY customer_ltv DESC) as quartile
    FROM mature_cohorts
) quartiled
WHERE quartile = 1;

/*
LTV PROJECTION USE:
- Set customer acquisition cost (CAC) targets
- CAC should be < 1/3 of LTV for healthy unit economics
- Example: If LTV = $300, max CAC = $100
*/

-- =====================================================
-- 10. COHORT HEALTH SCORECARD
-- =====================================================

-- Executive summary of cohort performance
WITH cohort_summary AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_unique_id) as cohort_size,
        -- Month 1 retention
        ROUND(
            100.0 * COUNT(DISTINCT customer_unique_id) FILTER (
                WHERE months_since_first_purchase >= 1
            ) / COUNT(DISTINCT customer_unique_id)
        , 2) as month_1_retention,
        -- Month 3 retention
        ROUND(
            100.0 * COUNT(DISTINCT customer_unique_id) FILTER (
                WHERE months_since_first_purchase >= 3
            ) / COUNT(DISTINCT customer_unique_id)
        , 2) as month_3_retention,
        -- Total revenue
        ROUND(SUM(order_value)::numeric, 2) as total_revenue,
        -- Revenue per customer
        ROUND(SUM(order_value) / COUNT(DISTINCT customer_unique_id)::numeric, 2) as revenue_per_customer
    FROM vw_customer_cohorts
    GROUP BY cohort_month
)
SELECT 
    cohort_month,
    cohort_size,
    month_1_retention,
    month_3_retention,
    revenue_per_customer,
    -- Health score (weighted average of retention and revenue)
    ROUND(
        (month_1_retention * 0.4 + 
         month_3_retention * 0.3 + 
         LEAST(revenue_per_customer / 2, 50) * 0.3)  -- Cap revenue impact
    , 2) as health_score,
    CASE 
        WHEN month_1_retention >= 25 AND month_3_retention >= 15 THEN '🟢 Healthy'
        WHEN month_1_retention >= 15 OR month_3_retention >= 10 THEN '🟡 Moderate'
        ELSE '🔴 At Risk'
    END as status
FROM cohort_summary
WHERE cohort_size >= 50  -- Exclude very small cohorts
ORDER BY cohort_month DESC;

/*
=================================================
COHORT ANALYSIS: KEY TAKEAWAYS
=================================================

WHAT SUCCESS LOOKS LIKE:
✓ Month 1 retention > 25%
✓ Month 3 retention > 15%
✓ Retention improving over time (newer cohorts better)
✓ Stable or increasing revenue per customer

RED FLAGS:
✗ Month 1 retention < 15%
✗ Declining retention across cohorts
✗ High customer acquisition, low retention
✗ Revenue per customer declining

ACTION PLAN:
1. Month 1 Focus: Post-purchase experience
   - Email onboarding sequence
   - Product recommendations
   - Loyalty incentive

2. Month 3-6: Engagement
   - Win-back campaigns
   - Exclusive offers
   - Content marketing

3. Month 12+: VIP Treatment
   - Loyalty programs
   - Early access to new products
   - Referral incentives

REPORTING CADENCE:
- Weekly: Monitor current cohort health
- Monthly: Full cohort analysis for leadership
- Quarterly: LTV projections and CAC targets

NEXT STEPS:
- Set retention targets by cohort age
- A/B test retention campaigns
- Calculate payback period on marketing spend
- Build automated cohort alerts
*/