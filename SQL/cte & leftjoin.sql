SELECT 
    o.order_id,
    o.order_status,
    r.review_score,
    CASE 
        WHEN r.review_score IS NULL THEN 'No Review'
        ELSE 'Has Review'
    END AS review_status
FROM orders o
LEFT JOIN order_reviews r ON o.order_id = r.order_id
LIMIT 100;
-- How many orders are missing reviews? --
SELECT
    
    COUNT(*) AS orders_without_reviews
FROM orders o
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE r.review_id IS NULL;

-- Average review score by product category (including products with no reviews) --
SELECT
    p.product_category_name,
    ROUND(AVG(r.review_score)::DECIMAL, 2) AS average_review_score,
    COUNT(r.review_id) AS total_reviews
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
GROUP BY p.product_category_name
ORDER BY total_reviews DESC;

--Rank sellers by total sales--
SELECT 
    s.seller_id,
    s.seller_city,
    COUNT(oi.order_item_id) AS items_sold,
    ROW_NUMBER() OVER (ORDER BY COUNT(oi.order_item_id) DESC) AS RANK
FROM sellers s
INNER JOIN order_items oi ON s.seller_id = oi.seller_id
GROUP BY s.seller_id, s.seller_city
ORDER BY items_sold DESC
LIMIT 10;
--Top 3 sellers per state--
WITH seller_stats AS (
    SELECT 
        s.seller_id,
        s.seller_state,
        s.seller_city,
        COUNT(oi.order_item_id) AS items_sold,
        ROW_NUMBER() OVER (PARTITION BY s.seller_state ORDER BY COUNT(oi.order_item_id) DESC) AS rank_in_state
    FROM sellers s
    INNER JOIN order_items oi ON s.seller_id = oi.seller_id
    GROUP BY s.seller_id, s.seller_state, s.seller_city
)
SELECT *
FROM seller_stats
WHERE rank_in_state <= 3
ORDER BY seller_state, rank_in_state ;

-- Top 5 customers per state by spending --
WITH customer_stats AS (
    SELECT 
        c.customer_id,
        c.customer_state,
        SUM(oi.price + oi.freight_value) AS total_spending,
        ROW_NUMBER() OVER (PARTITION BY c.customer_state ORDER BY SUM(oi.price + oi.freight_value) DESC) AS rank
    FROM customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.customer_state
)
SELECT 
    customer_id,
    customer_state,
    total_spending,
    rank
FROM customer_stats
WHERE rank <= 5
ORDER BY customer_state, rank ASC;

--Running Totals--Cumulative revenue by month--
WITH monthly_revenue AS(
SELECT 
    DATE_TRUNC('month',o.order_purchase_timestamp) AS MONTH,
	SUM(oi.price) AS revenue
	FROM orders o 
	INNER JOIN order_items oi ON o.order_id = oi.order_id
	WHERE o.order_status ='delivered'
	GROUP BY DATE_TRUNC('month',o.order_purchase_timestamp)
)
SELECT 
    month,
	revenue,
	SUM(revenue) OVER (ORDER BY MONTH) AS cumulative_revenue
	FROM monthly_revenue
	ORDER BY month;

-- REVENUE PER MONTH --
WITH monthly_revenue AS(
SELECT
    SUM(oi.price+oi.freight_value) AS revenue,
	DATE_TRUNC('month',o.order_purchase_timestamp) AS month
	FROM order_items oi
	INNER JOIN orders o ON oi.order_id = o.order_id
	GROUP BY DATE_TRUNC('month',o.order_purchase_timestamp)
)
SELECT
month,
revenue
FROM monthly_revenue
ORDER BY month;

-- Monthly Revenue + Monthly Revenue Growth using LAG --
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        ROUND(SUM(oi.price + oi.freight_value)::DECIMAL, 2) AS revenue
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY month))::DECIMAL, 2) AS revenue_growth,
    ROUND(((revenue - LAG(revenue) OVER (ORDER BY month)) / LAG(revenue) OVER (ORDER BY month) * 100)::DECIMAL, 2) AS growth_percentage
FROM monthly_revenue
ORDER BY month;
-- Yearly growth - Are we growing or plateaued?--
WITH yearly_revenue AS(
SELECT
    DATE_TRUNC('year',o.order_purchase_timestamp) AS year,
	ROUND(SUM(oi.price+oi.freight_value)::DECIMAL,2) AS revenue
	FROM order_items oi
	INNER JOIN orders o ON oi.order_id = o.order_id
	GROUP BY DATE_TRUNC('year',o.order_purchase_timestamp)
)
SELECT
year,
revenue,
LAG(revenue) OVER (ORDER BY year) AS previous_year_revenue,
     ROUND((revenue - LAG(revenue) OVER (ORDER BY year))::DECIMAL, 2) AS revenue_growth,
     ROUND((revenue - LAG(revenue) OVER (ORDER BY year)) / LAG(revenue) OVER (ORDER BY year)::DECIMAL, 2) AS growth_percentage
	 FROM yearly_revenue
	 ORDER BY year;

-- Which state is growing, which is declining (monthly)? --
WITH state_monthly_revenue AS (
    SELECT
        c.customer_state,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        ROUND(SUM(oi.price + oi.freight_value)::DECIMAL, 2) AS revenue
    FROM customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_state, DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT
    customer_state,
    month,
    revenue,
    LAG(revenue) OVER (PARTITION BY customer_state ORDER BY month) AS previous_month_revenue,
    ROUND((revenue - LAG(revenue) OVER (PARTITION BY customer_state ORDER BY month))::DECIMAL, 2) AS revenue_growth,
    ROUND(((revenue - LAG(revenue) OVER (PARTITION BY customer_state ORDER BY month)) / LAG(revenue) OVER (PARTITION BY customer_state ORDER BY month))::DECIMAL, 2) AS growth_percentage
FROM state_monthly_revenue
ORDER BY customer_state, month DESC ;
