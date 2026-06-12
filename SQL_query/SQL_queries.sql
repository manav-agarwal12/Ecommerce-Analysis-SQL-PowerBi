-- PART 1
-- Concepts: SELECT, WHERE, GROUP BY, ORDER BY, COUNT, AVG, JOIN basics

--  How many total orders are there?
SELECT COUNT(*) AS total_orders
FROM olist_orders;

-- All order statuses and their counts

SELECT order_status ,
COUNT(*) as Count
FROM olist_orders
group by order_status
order by count desc;

-- Customers per state (Top 10)

select customer_state,
count(distinct customer_unique_id) as unique_customers
from olist_customers
group by customer_state
order by unique_customers desc
limit 10;

 -- Payment method breakdown
 
select payment_type,
 count(*) as total_transactions,
 round(sum(payment_value), 2) as total_revenue,
 round(avg(payment_value), 2) as avg_transaction_value
 from olist_order_payments
 group by payment_type
 order by total_revenue desc;
  
-- Average review score + star breakdown

select round(avg(review_score), 2) as avg_review_score,
count(*) as total_reviews ,
sum(case when review_score = 5 then 1 else 0 end) as five_star,
sum(case when review_score = 4 then 1 else 0 end) as four_star,
sum(case when review_score = 3 then 1 else 0 end) three_star,
sum(case when review_score = 2 then 1 else 0 end) as two_star,
sum(case when review_score = 1 then 1 else 0 end) as one_star
from olist_order_reviews;

-- Top 10 product categories by product count

select t.product_category_name_english as product_category,
count(p.product_id) as product_count
from olist_products p
join product_category_name_translation t
on p.product_category_name = t.product_category_name
group by product_category
order by product_count
limit 10;

-- Total revenue per year
 select year(o.order_purchase_timestamp) as year,
 round(sum(oi.price + oi.freight_value), 2) as total_revenue
 from olist_orders o
 join olist_order_items oi
 on o.order_id = oi.order_id
 group by year
 order by year
 
 
 -- PART 2
 -- Concepts: Multi-table JOINs, CASE, DATE functions, Subqueries, HAVING
 
 -- Monthly revenue trend
 
 SELECT 
    YEAR(o.order_purchase_timestamp)                          AS year,
    MONTH(o.order_purchase_timestamp)                         AS month_num,
    DATE_FORMAT(o.order_purchase_timestamp, '%b %Y')          AS month_label,
    ROUND(SUM(oi.price), 2)                                   AS product_revenue,
    ROUND(SUM(oi.freight_value), 2)                           AS freight_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2)                AS total_revenue
FROM olist_orders o
JOIN olist_order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY year, month_num, month_label
ORDER BY year, month_num;

-- Top 10 sellers by revenue with ratings

select s.seller_id, seller_city, seller_state,
count(distinct oi.order_id) as total_orders,
round(sum(oi.price), 2)  as total_revenue,
round(avg(r.review_score), 2) as avg_rating
from olist_sellers s
join olist_order_items oi on s.seller_id = oi.seller_id
join olist_orders o on o.order_id = oi.order_id
left join olist_order_reviews r on o.order_id = r.order_id
where o.order_status = 'delivered'
group by s.seller_id, seller_city, seller_state
order by total_revenue desc
limit 10;

-- Average delivery time by state

select c.customer_state,
count(o.order_id) as total_orders,
ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1)      AS avg_delivery_days,
ROUND(AVG(DATEDIFF(o.order_estimated_delivery_date, o.order_delivered_customer_date)), 1) AS avg_early_late_days
FROM olist_orders o
JOIN olist_customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;

-- Revenue by product category (English names)
SELECT 
    COALESCE(t.product_category_name_english, 'Unknown') AS category,
    COUNT(DISTINCT o.order_id)                            AS orders,
    ROUND(SUM(oi.price), 2)                               AS revenue,
    ROUND(AVG(oi.price), 2)                               AS avg_price
FROM olist_order_items oi
JOIN olist_orders o ON oi.order_id = o.order_id
JOIN olist_products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 15;

-- Customer satisfaction score per category
SELECT 
    t.product_category_name_english                                       AS category,
    COUNT(r.review_id)                                                    AS review_count,
    ROUND(AVG(r.review_score), 2)                                         AS avg_score,
    SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END)                  AS positive,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)                  AS negative,
    ROUND(100.0 * SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                                   AS satisfaction_pct
FROM olist_order_reviews r
JOIN olist_orders o ON r.order_id = o.order_id
JOIN olist_order_items oi ON o.order_id = oi.order_id
JOIN olist_products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY category
HAVING review_count > 100
ORDER BY avg_score DESC;

-- Late delivery impact on review score

SELECT 
    CASE 
        WHEN DATEDIFF(o.order_delivered_customer_date,
                      o.order_estimated_delivery_date) < -5  THEN 'Very Early (5+ days)'
        WHEN DATEDIFF(o.order_delivered_customer_date,
                      o.order_estimated_delivery_date) < 0   THEN 'Early (1-5 days)'
        WHEN DATEDIFF(o.order_delivered_customer_date,
                      o.order_estimated_delivery_date) = 0   THEN 'On Time'
        WHEN DATEDIFF(o.order_delivered_customer_date,
                      o.order_estimated_delivery_date) <= 5  THEN 'Slightly Late (1-5 days)'
        ELSE                                                       'Very Late (5+ days)'
    END                               AS delivery_bucket,
    COUNT(*)                          AS order_count,
    ROUND(AVG(r.review_score), 2)     AS avg_review_score
FROM olist_orders o
JOIN olist_order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_bucket
ORDER BY avg_review_score DESC;

-- Repeat vs one-time buyers
SELECT 
    purchase_frequency,
    COUNT(*)                                                  AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2)        AS pct_of_customers
FROM (
    SELECT customer_unique_id, COUNT(o.order_id) AS purchase_frequency
    FROM olist_customers c
    JOIN olist_orders o ON c.customer_id = o.customer_id
    GROUP BY customer_unique_id
) customer_orders
GROUP BY purchase_frequency
ORDER BY purchase_frequency;

-- CTEs
-- Running cumulative revenue + Month-over-Month growth

WITH monthly_revenue AS (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        ROUND(SUM(oi.price), 2)                          AS monthly_revenue
    FROM olist_orders o
    JOIN olist_order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY month
)
SELECT 
    month,
    monthly_revenue,
    ROUND(SUM(monthly_revenue) OVER (ORDER BY month), 2)                           AS cumulative_revenue,
    ROUND(monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month), 2)         AS mom_change,
    ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month))
          / LAG(monthly_revenue) OVER (ORDER BY month), 1)                         AS mom_growth_pct
FROM monthly_revenue
ORDER BY month;

 -- window functions 
  -- Seller ranking by state using DENSE_RANK
  WITH seller_stats AS (
    SELECT 
        s.seller_id,
        s.seller_state,
        ROUND(SUM(oi.price), 2)       AS total_revenue,
        COUNT(DISTINCT oi.order_id)   AS total_orders
    FROM olist_sellers s
    JOIN olist_order_items oi ON s.seller_id = oi.seller_id
    JOIN olist_orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id, s.seller_state
)
SELECT 
    seller_id,
    seller_state,
    total_revenue,
    total_orders,
    DENSE_RANK() OVER (PARTITION BY seller_state ORDER BY total_revenue DESC) AS rank_in_state,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC)                           AS overall_rank
FROM seller_stats
ORDER BY seller_state, rank_in_state;

-- RFM Customer Segmentation
WITH rfm_raw AS (
    SELECT 
        c.customer_unique_id,
        DATEDIFF('2018-10-01', MAX(o.order_purchase_timestamp)) AS recency_days,
        COUNT(DISTINCT o.order_id)                              AS frequency,
        ROUND(SUM(oi.price), 2)                                 AS monetary
    FROM olist_customers c
    JOIN olist_orders o ON c.customer_id = o.customer_id
    JOIN olist_order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM rfm_raw
),
rfm_segmented AS (
    SELECT *,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3                   THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                   THEN 'Recent Customers'
            WHEN r_score >= 3 AND m_score >= 3                   THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3  THEN 'At Risk'
            WHEN r_score <= 1 AND f_score >= 4 AND m_score >= 4  THEN 'Cant Lose Them'
            WHEN r_score <= 2 AND f_score <= 2                   THEN 'Lost Customers'
            ELSE 'Others'
        END AS customer_segment
    FROM rfm_scored
)
SELECT 
    customer_segment,
    COUNT(*)                          AS customer_count,
    ROUND(AVG(recency_days), 0)       AS avg_recency_days,
    ROUND(AVG(frequency), 1)          AS avg_frequency,
    ROUND(AVG(monetary), 2)           AS avg_monetary_value,
    ROUND(SUM(monetary), 2)           AS total_revenue
FROM rfm_segmented
GROUP BY customer_segment
ORDER BY total_revenue DESC;

-- Top Products with Percentile Ranking
WITH product_revenue AS (
    SELECT 
        p.product_id,
        COALESCE(t.product_category_name_english,
                 p.product_category_name)         AS category,
        COUNT(oi.order_id)                        AS times_ordered,
        ROUND(SUM(oi.price), 2)                   AS total_revenue,
        ROUND(AVG(oi.price), 2)                   AS avg_price
    FROM olist_products p
    JOIN olist_order_items oi ON p.product_id = oi.product_id
    JOIN olist_orders o ON oi.order_id = o.order_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY p.product_id, category
)
SELECT 
    product_id, category, times_ordered, total_revenue, avg_price,
    ROUND(PERCENT_RANK() OVER (ORDER BY total_revenue) * 100, 1) AS revenue_percentile,
    CASE 
        WHEN PERCENT_RANK() OVER (ORDER BY total_revenue) >= 0.9  THEN 'Top 10%'
        WHEN PERCENT_RANK() OVER (ORDER BY total_revenue) >= 0.75 THEN 'Top 25%'
        WHEN PERCENT_RANK() OVER (ORDER BY total_revenue) >= 0.5  THEN 'Above Average'
        ELSE 'Below Average'
    END AS product_tier
FROM product_revenue
ORDER BY total_revenue DESC
LIMIT 30;
 
-- Geographic Revenue by State
WITH state_metrics AS (
    SELECT 
        c.customer_state,
        COUNT(DISTINCT c.customer_unique_id)                                 AS unique_customers,
        COUNT(DISTINCT o.order_id)                                           AS total_orders,
        ROUND(SUM(oi.price), 2)                                              AS total_revenue,
        ROUND(AVG(oi.price), 2)                                              AS avg_order_value,
        ROUND(AVG(r.review_score), 2)                                        AS avg_satisfaction,
        ROUND(AVG(DATEDIFF(o.order_delivered_customer_date,
                           o.order_purchase_timestamp)), 1)                  AS avg_delivery_days
    FROM olist_customers c
    JOIN olist_orders o ON c.customer_id = o.customer_id
    JOIN olist_order_items oi ON o.order_id = oi.order_id
    LEFT JOIN olist_order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state
)
SELECT *,
    ROUND(total_revenue / unique_customers, 2)                                AS revenue_per_customer,
    ROUND(100.0 * total_revenue / SUM(total_revenue) OVER(), 2)               AS revenue_share_pct,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC)                            AS revenue_rank
FROM state_metrics
ORDER BY total_revenue DESC;
 
 
 