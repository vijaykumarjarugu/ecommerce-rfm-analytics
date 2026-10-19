-- ==========================================================
-- E-Commerce RFM Segmentation & Customer Analytics View
-- Database: PostgreSQL (ecommerce_analytics)
-- ==========================================================

WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp::timestamp AS purchase_date,
        p.payment_value
    FROM olist_customers c
    JOIN olist_orders o 
        ON c.customer_id = o.customer_id
    JOIN (
        SELECT order_id, SUM(payment_value) AS payment_value
        FROM olist_order_payments
        GROUP BY order_id
    ) p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
),

rfm_metrics AS (
    SELECT 
        customer_unique_id,
        (SELECT MAX(purchase_date)::date FROM customer_orders) - MAX(purchase_date)::date AS recency_days,
        COUNT(DISTINCT order_id) AS frequency,
        COALESCE(SUM(payment_value), 0) AS monetary
    FROM customer_orders
    GROUP BY customer_unique_id
),

rfm_scores AS (
    SELECT 
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_metrics
)

SELECT 
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Promising'
        WHEN r_score >= 3 AND f_score <= 2 THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk (High Value Repeaters)'
        ELSE 'Lost / Churned One-Timers'
    END AS customer_segment
FROM rfm_scores;