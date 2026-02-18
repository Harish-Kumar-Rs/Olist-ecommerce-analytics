-- Identify repeat customers and their favorite categories
WITH customer_purchase_count AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
repeat_customers AS (
    SELECT customer_unique_id
    FROM customer_purchase_count
    WHERE total_orders > 1
),
repeat_customer_purchases AS (
    SELECT 
        p.product_category_name,
        COUNT(oi.order_item_id) AS items_purchased,
        SUM(oi.price+oi.freight_value) AS total_revenue
    FROM repeat_customers rc
    INNER JOIN customers c ON rc.customer_unique_id = c.customer_unique_id
    INNER JOIN orders o ON c.customer_id = o.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY p.product_category_name
)
SELECT 
    product_category_name,
    items_purchased,
    total_revenue,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2) AS revenue_percentage
FROM repeat_customer_purchases
ORDER BY total_revenue DESC
LIMIT 10;
-- What do new customers buy --

WITH customer_purchase_count AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
new_customers AS (
    SELECT customer_unique_id
    FROM customer_purchase_count
    WHERE total_orders = 1
),
new_customer_purchases AS (
    SELECT 
        p.product_category_name,
        COUNT(oi.order_item_id) AS items_purchased,
        SUM(oi.price+oi.freight_value) AS total_revenue
    FROM new_customers nc
    INNER JOIN customers c ON nc.customer_unique_id = c.customer_unique_id
    INNER JOIN orders o ON c.customer_id = o.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY p.product_category_name
)
SELECT 
    product_category_name,
    items_purchased,
    total_revenue,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2) AS revenue_percentage
FROM new_customer_purchases
ORDER BY total_revenue DESC
LIMIT 10;
WITH category_customer_behavior AS (
    SELECT 
        p.product_category_name,
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS orders_in_category
    FROM products p
    INNER JOIN order_items oi ON p.product_id = oi.product_id
    INNER JOIN orders o ON oi.order_id = o.order_id
    INNER JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
        AND p.product_category_name IS NOT NULL
    GROUP BY p.product_category_name, c.customer_unique_id
),
retention_stats AS (
    SELECT 
        product_category_name,
        COUNT(DISTINCT customer_unique_id) AS total_customers,
        COUNT(DISTINCT CASE WHEN orders_in_category > 1 THEN customer_unique_id END) AS repeat_customers
    FROM category_customer_behavior
    GROUP BY product_category_name
)
SELECT 
    product_category_name,
    total_customers,
    repeat_customers,
    ROUND(repeat_customers * 100.0 / NULLIF(total_customers, 0), 2) AS retention_rate_pct
FROM retention_stats
WHERE total_customers >= 100  -- Minimum sample size
ORDER BY retention_rate_pct DESC
LIMIT 20;

WITH order_metrics AS (
    SELECT 
        o.order_id,
        EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400 AS delivery_days,
        r.review_score
    FROM orders o
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
        AND o.order_purchase_timestamp IS NOT NULL
        AND r.review_score IS NOT NULL
)
SELECT 
    CASE 
        WHEN delivery_days <= 7 THEN '0-7 days'
        WHEN delivery_days <= 14 THEN '8-14 days'
        WHEN delivery_days <= 21 THEN '15-21 days'
        WHEN delivery_days <= 30 THEN '22-30 days'
        ELSE '30+ days'
    END AS delivery_time_bucket,
    COUNT(*) AS order_count,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(AVG(delivery_days), 1) AS avg_delivery_days
FROM order_metrics
GROUP BY delivery_time_bucket
ORDER BY avg_delivery_days;


-- Step 1: Calculate delivery speed and avg review
WITH order_metrics AS (
    SELECT 
        o.order_id,
        EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400 AS delivery_days,
        r.review_score,
        SUM(oi.price + oi.freight_value) AS order_revenue
    FROM orders o
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.order_delivered_customer_date, o.order_purchase_timestamp, r.review_score
),
delivery_rating AS (
    SELECT
        CASE 
            WHEN delivery_days <= 7 THEN 'Fast'
            WHEN delivery_days <= 14 THEN 'Medium'
            ELSE 'Slow'
        END AS delivery_speed,
        AVG(review_score) AS avg_rating,
        SUM(order_revenue) AS revenue,
        COUNT(order_id) AS order_count
    FROM order_metrics
    GROUP BY delivery_speed
),
-- Step 2: Simulate 20% improvement: shift 20% of Medium and Slow orders to Fast
simulated_revenue AS (
    SELECT
        delivery_speed,
        revenue,
        order_count,
        CASE 
            WHEN delivery_speed = 'Fast' THEN revenue + 0.2 * (SELECT SUM(revenue) FROM delivery_rating WHERE delivery_speed IN ('Medium','Slow'))
            ELSE revenue * 0.8  -- remaining 80% of Medium/Slow revenue
        END AS projected_revenue
    FROM delivery_rating
)
SELECT
    delivery_speed,
    revenue AS current_revenue,
    projected_revenue,
    ROUND((projected_revenue - revenue)::DECIMAL,2) AS revenue_lift
FROM simulated_revenue
ORDER BY delivery_speed;



    