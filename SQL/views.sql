-- VIEW 1: Monthly Performance Dashboard
CREATE OR REPLACE VIEW vw_monthly_performance AS
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price + oi.freight_value)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(oi.price)::DECIMAL, 2) AS avg_order_value,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(DISTINCT CASE WHEN o.order_status = 'canceled' THEN o.order_id END) AS canceled_orders,
    ROUND(COUNT(DISTINCT CASE WHEN o.order_status = 'canceled' THEN o.order_id END) * 100.0 / 
          NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS cancellation_rate
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;

-- VIEW 2: Category Performance
CREATE OR REPLACE VIEW vw_category_performance AS
SELECT 
    p.product_category_name AS category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(oi.price)::DECIMAL, 2) AS avg_price,
    ROUND(AVG(r.review_score), 2) AS avg_rating,
    COUNT(r.review_score) AS review_count
FROM products p
INNER JOIN order_items oi ON p.product_id = oi.product_id
INNER JOIN orders o ON oi.order_id = o.order_id
INNER JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND p.product_category_name IS NOT NULL
GROUP BY p.product_category_name;

-- VIEW 3: State Performance
CREATE OR REPLACE VIEW vw_state_performance AS
SELECT 
    c.customer_state AS state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price + oi.freight_value)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400)::DECIMAL, 1) AS avg_delivery_days,
    ROUND(AVG(r.review_score), 2) AS avg_rating,
    COUNT(DISTINCT CASE WHEN o.order_status = 'canceled' THEN o.order_id END) AS canceled_orders
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
GROUP BY c.customer_state;

-- VIEW 4: Seller Performance Rankings
CREATE OR REPLACE VIEW vw_seller_rankings AS
SELECT 
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(oi.order_item_id) AS total_items_sold,
    ROUND(SUM(oi.price)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_carrier_date - o.order_purchase_timestamp)) / 86400)::DECIMAL, 1) AS avg_shipping_days,
    ROW_NUMBER() OVER (ORDER BY SUM(oi.price) DESC) AS revenue_rank
FROM sellers s
INNER JOIN order_items oi ON s.seller_id = oi.seller_id
INNER JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_carrier_date IS NOT NULL
GROUP BY s.seller_id, s.seller_state, s.seller_city
HAVING COUNT(DISTINCT oi.order_id) >= 5;

-- VIEW 5: Customer Segments
CREATE OR REPLACE VIEW vw_customer_segments AS
WITH customer_stats AS (
    SELECT 
        c.customer_unique_id,
        c.customer_state,
        c.customer_city,
        COUNT(DISTINCT o.order_id) AS total_orders,
        ROUND(SUM(oi.price + oi.freight_value)::DECIMAL, 2) AS total_spent,
        MIN(o.order_purchase_timestamp) AS first_order_date,
        MAX(o.order_purchase_timestamp) AS last_order_date
    FROM customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_state, c.customer_city
)
SELECT 
    customer_unique_id,
    customer_state,
    customer_city,
    total_orders,
    total_spent,
    first_order_date,
    last_order_date,
    CASE 
        WHEN total_spent > 1000 AND total_orders > 3 THEN 'VIP'
        WHEN total_spent > 300 OR total_orders > 1 THEN 'Regular'
        ELSE 'One-time'
    END AS customer_segment,
    CASE 
        WHEN total_orders = 1 THEN 'New'
        ELSE 'Repeat'
    END AS customer_type
FROM customer_stats;

-- VIEW 6: Product Performance Detail
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT 
    p.product_id,
    p.product_category_name AS category,
    COUNT(DISTINCT oi.order_id) AS times_ordered,
    ROUND(SUM(oi.price)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(oi.price)::DECIMAL, 2) AS avg_price,
    ROUND(AVG(r.review_score), 2) AS avg_rating,
    COUNT(r.review_score) AS review_count,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_photos_qty
FROM products p
INNER JOIN order_items oi ON p.product_id = oi.product_id
INNER JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_id, p.product_category_name, 
         p.product_weight_g, p.product_length_cm, 
         p.product_height_cm, p.product_width_cm, p.product_photos_qty;

-- Create a new view: vw_category_full_performance
CREATE OR REPLACE VIEW vw_category_full_performance AS
WITH customer_orders AS (
    SELECT 
        o.customer_id,
        p.product_category_name,
        COUNT(o.order_id) OVER (PARTITION BY o.customer_id, p.product_category_name) AS orders_per_category
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL
),
retention_data AS (
    SELECT 
        product_category_name,
        COUNT(DISTINCT customer_id) AS total_customers,
        COUNT(DISTINCT CASE WHEN orders_per_category > 1 THEN customer_id END) AS repeat_customers
    FROM customer_orders
    GROUP BY product_category_name
    HAVING COUNT(DISTINCT customer_id) >= 50
),
revenue_data AS (
    SELECT 
        p.product_category_name,
        ROUND(SUM(oi.price)::DECIMAL, 2) AS total_revenue,
        ROUND(AVG(r.review_score), 2) AS avg_rating
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL
    GROUP BY p.product_category_name
)
SELECT 
    rd.product_category_name,
    ret.total_customers,
    ret.repeat_customers,
    ROUND(ret.repeat_customers * 100.0 / NULLIF(ret.total_customers,0), 2) AS retention_rate,
    rd.total_revenue,
    rd.avg_rating,
    CASE
        WHEN ROUND(ret.repeat_customers * 100.0 / NULLIF(ret.total_customers,0), 2) >= 5
             AND rd.total_revenue > 300000
             AND rd.avg_rating >= 4 THEN 'INVEST HEAVILY'
        WHEN ROUND(ret.repeat_customers * 100.0 / NULLIF(ret.total_customers,0), 2) >= 3
             AND rd.total_revenue > 150000 THEN 'MODERATE INVESTMENT'
        ELSE 'LOW PRIORITY'
    END AS marketing_recommendation
FROM retention_data ret
JOIN revenue_data rd 
  ON ret.product_category_name = rd.product_category_name;

  --monthly trend view --
  CREATE OR REPLACE VIEW vw_state_monthly_trends AS
SELECT
    c.customer_state AS state,
    DATE_TRUNC('month', o.order_purchase_timestamp) AS year_month,
    ROUND(SUM(oi.price)::DECIMAL, 2) AS monthly_revenue,
    COUNT(DISTINCT o.order_id) AS monthly_orders
FROM orders o
JOIN order_items oi 
    ON o.order_id = oi.order_id
JOIN customers c 
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY
    c.customer_state,
    DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY
    state,
    year_month;
--Month view 2 --
CREATE OR REPLACE VIEW vw_monthly_performance_clean AS
WITH first_order AS (
    -- Get first order date per customer
    SELECT
        customer_id,
        MIN(order_purchase_timestamp) AS first_order_date
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY customer_id
),
monthly_orders AS (
    -- Aggregate orders per month per customer
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS year_month,
        o.customer_id,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        DATE_TRUNC('month', o.order_purchase_timestamp),
        o.customer_id
)
SELECT
    mo.year_month,
    CASE 
        WHEN mo.year_month = DATE_TRUNC('month', fo.first_order_date) THEN 'New'
        ELSE 'Repeat'
    END AS customer_type,
    COUNT(DISTINCT mo.customer_id) AS customer_count,
    SUM(mo.revenue) AS revenue
FROM monthly_orders mo
JOIN first_order fo ON mo.customer_id = fo.customer_id
GROUP BY
    mo.year_month,
    CASE 
        WHEN mo.year_month = DATE_TRUNC('month', fo.first_order_date) THEN 'New'
        ELSE 'Repeat'
    END
ORDER BY
    mo.year_month,
    customer_type;

-- DATE AND STATE SLICERS -- 

CREATE OR REPLACE VIEW dim_date AS
SELECT DISTINCT
    DATE_TRUNC('month', order_purchase_timestamp)::DATE AS month
FROM orders
WHERE order_status = 'delivered'
ORDER BY month;
----------------
CREATE OR REPLACE VIEW dim_state AS
SELECT DISTINCT
    customer_state AS state
FROM customers
ORDER BY state;



