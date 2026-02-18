SELECT o.order_id,
o.order_status,
c.customer_city,
c.customer_state
FROM orders o 
INNER JOIN customers c  ON o.customer_id = c.customer_id
LIMIT 10;

-- See what products were ordered
SELECT 
    oi.order_id,
    oi.price,
    p.product_category_name
FROM order_items oi
INNER JOIN products p ON oi.product_id = p.product_id;

--ORDERS WITH REVIEW --
SELECT 
o.order_id,
o.order_status,
rw.review_score
FROM orders o
INNER JOIN order_reviews rw ON o.order_id = rw.order_id;
-- Which city's customers are buying what?

SELECT 
    c.customer_city,
    c.customer_state,
    oi.price,
    p.product_category_name
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
LIMIT 20;
--lorenz curve --
CREATE OR REPLACE VIEW vw_customer_revenue_ranked AS
SELECT
    customer_id,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    COUNT(*) OVER () AS total_customers,
    SUM(total_revenue) OVER () AS total_revenue_all,
    SUM(total_revenue) OVER (
        ORDER BY total_revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM (
    SELECT
        o.customer_id,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
) t;

--GINI--
--CREATE OR REPLACE VIEW vw_gini_customer_revenue AS
WITH customer_revenue AS (
    SELECT
        o.customer_id,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
),
ranked AS (
    SELECT
        customer_id,
        total_revenue,
        RANK() OVER (ORDER BY total_revenue ASC) AS revenue_rank,
        COUNT(*) OVER () AS n,
        SUM(total_revenue) OVER () AS total_revenue_all
    FROM customer_revenue
),
calc AS (
    SELECT
        n,
        total_revenue_all,
        SUM(revenue_rank * total_revenue) AS sum_rank_revenue
    FROM ranked
    GROUP BY n, total_revenue_all
)
SELECT
    1 - (2.0 / (n - 1)) *
        (n - (sum_rank_revenue / total_revenue_all)) AS gini_coefficient
FROM calc;

