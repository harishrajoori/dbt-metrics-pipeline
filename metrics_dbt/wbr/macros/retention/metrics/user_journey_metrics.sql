{%- macro user_journey_metrics() -%}
/* -- Script Name = user_journey_metrics.sql :: BEGIN -- */
WITH aggregated_journey_metrics AS
(
    /* ---
    Below CTE is to extract data from "fm_products", focussing on only
    the requisite attributes that are needed for LTV Segment = Retention
    --- */

    SELECT
        year_month_day
        ,product_pl
        ,region
        ,sub_category
        ,customer_count
        ,order_count
        ,net_sales_amount
    FROM
    (
        SELECT
            year_month_day
            ,product_pl
            ,region
            ,sub_category
            ,COUNT(DISTINCT order_customer_id) AS customer_count
            ,COUNT(DISTINCT transaction_order_id) AS order_count
            ,IF((product_pl = 'UK' OR product_pl IS NULL), SUM(m_net_sales_amount_gbp), SUM(m_net_sales_amount_eur)) AS net_sales_amount
        FROM
        (
            SELECT
                year_month_day
                ,product_pl
                ,region
                ,CASE WHEN fare_train_classification_name_longest_duration = 'long distance' AND product_travel_classification_name NOT IN ('Commuting','Business')
                      THEN 'Leisure and Long Distance'
                      WHEN fare_train_classification_name_longest_duration = 'regional' AND product_travel_classification_name = 'Commuting'
                      THEN 'Commute and Regional'
                 END AS sub_category
                ,order_customer_id
                ,transaction_order_id
                ,m_net_sales_amount_gbp
                ,m_net_sales_amount_eur
            FROM (
                {{ fm_products_data() }}
            ) fm
            WHERE
                ( product_pl = 'EU' AND region IN  {{ var("retention_mart")["region"] }} ) -- regions specific to EU only
                OR
                ( product_pl = 'UK' AND region = 'United Kingdom' ) -- regions specific to UK only
        )
        GROUP BY CUBE(year_month_day, product_pl, region, sub_category)
   )
   WHERE year_month_day IS NOT NULL
    AND sub_category IS NOT NULL
)

, combined_metrics AS
(
    select
        agg.*
    from aggregated_journey_metrics agg

    union all
    -- (Leisure or Commute) and (Regional or Long Distance) metrics --
    select
        year_month_day
        ,product_pl
        ,region
        ,'All' AS sub_category
        ,SUM(customer_count) as customer_count
        ,SUM(order_count) as customer_count
        ,SUM(net_sales_amount) as net_sales_amount
    from aggregated_journey_metrics agg
    group by 1,2,3
)


SELECT
    year_month_day AS year_month_day
    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
    , product_pl
    , region
    /* ------------------------------------------------------------------------------------------------------- -- */
    , CASE WHEN sub_category = 'All' THEN 'All' ELSE category END AS category
    , sub_category
    , metric_name
    , ROUND(
          CASE
              WHEN category = 'Volume' AND metric_name = 'Number of Customers' THEN customer_count
              WHEN category = 'Volume Orders' AND metric_name = 'Total number of Orders' THEN order_count
              WHEN category = 'Sales' AND metric_name = 'Net Sales Amount' THEN net_sales_amount
              WHEN category = 'Frequency' AND metric_name = 'Transactions per Customer' THEN CAST(order_count as decimal(38, 2))/customer_count
          END, 4) AS metric_value
FROM
    combined_metrics
CROSS JOIN UNNEST(
        ARRAY[
            ROW('Volume', 'Number of Customers'),
            ROW('Volume Orders', 'Total number of Orders'),
            ROW('Sales', 'Net Sales Amount'),
            ROW('Frequency', 'Transactions per Customer')
        ]
    ) AS t(category, metric_name)
/* -- Script Name = user_journey_metrics.sql :: END -- */
{%- endmacro -%}