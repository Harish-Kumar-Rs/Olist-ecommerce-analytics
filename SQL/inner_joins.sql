--TOTAL REVENUE --
SELECT SUM(price) AS total_revenue
FROM order_items
WHERE price IS NOT NULL AND price >0;
--AVERAGE ORDER VALUE--
SELECT COUNT(DISTINCT order_id) AS total_no_of_orders,
ROUND(SUM(price)/COUNT(DISTINCT order_id)::NUMERIC,2) AS Avg_order_value
FROM order_items;
--STATE WISE REVENUE--
SELECT 
c.customer_state,
SUM(oi.price) AS total_revenue
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id	
INNER JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY total_revenue DESC;
--COUNT OF ORDERS--
SELECT 
COUNT(DISTINCT order_id) AS Total_orders
FROM orders;
--COUNT OF CUSTOMERS--
SELECT COUNT(DISTINCT customer_unique_id) AS total_customers
FROM customers;
--STATE WISE CUSTOMER COUNT--
SELECT customer_state,COUNT(DISTINCT customer_unique_id) Total_customers
FROM customers
GROUP BY customer_state
ORDER BY total_customers DESC;
--Top 5 Product Categories by Revenue--
SELECT 
    p.product_category_name,
    SUM(oi.price) AS total_revenue
FROM products p
INNER JOIN order_items oi ON p.product_id = oi.product_id
INNER JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'  -- Only count delivered orders
GROUP BY p.product_category_name
ORDER BY total_revenue DESC 
LIMIT 5;
--Top 10 Cities by Number of Orders--
SELECT 
c.customer_city,
COUNT(DISTINCT o.order_id) AS total_orders
FROM customers c
INNER JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_city
ORDER BY total_orders DESC
LIMIT 10;
--Average Price per Product Category--
SELECT
p.product_category_name,
ROUND(AVG(oi.price)::DECIMAL, 2) AS average_product_price
FROM products p
INNER JOIN order_items oi ON p.product_id = oi.product_id
WHERE p.product_category_name IS NOT NULL
GROUP BY p.product_category_name
ORDER BY average_product_price DESC;
-- STATE WISE ORDER COUNT--
SELECT 
    c.customer_state,
    COUNT(o.order_id) as order_count
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY order_count DESC;
--WHICH SELLER HAS SOLD MOST ITEMS--
SELECT
    s.seller_id,
    COUNT(oi.order_item_id) AS total_items_sold
FROM sellers s 
INNER JOIN order_items oi ON s.seller_id = oi.seller_id
GROUP BY s.seller_id
ORDER BY total_items_sold DESC
LIMIT 10;
-- REVENUE BY PAYMENT TYPE --
-- REVENUE BY PAYMENT TYPE --
WITH order_revenues AS (
    SELECT 
        order_id,
        SUM(price + freight_value) AS order_total
    FROM order_items
    GROUP BY order_id
)
SELECT
    op.payment_type,
    COUNT(DISTINCT op.order_id) AS order_count,
    COUNT(oi.order_item_id) AS total_items,
    ROUND(SUM(or_rev.order_total)::DECIMAL, 2) AS total_revenue
FROM order_payments op
INNER JOIN order_items oi ON op.order_id = oi.order_id
INNER JOIN order_revenues or_rev ON op.order_id = or_rev.order_id
GROUP BY op.payment_type
ORDER BY total_revenue DESC;
-- Top 5 customers by total spending--
SELECT 
c.customer_id,
SUM(oi.price + oi.freight_value) AS total_spending
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'  -- Only completed orders
GROUP BY c.customer_id
ORDER BY total_spending DESC
LIMIT 5;

