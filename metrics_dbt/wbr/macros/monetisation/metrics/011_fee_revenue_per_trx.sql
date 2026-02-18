{%- macro fee_revenue_per_trx() -%}
/* -- Script Name = 011_fee_revenue_per_trx.sql :: BEGIN -- */
SELECT
    year_month_day
    , product_pl
    , region
    , 'All' AS category
    , 'All' AS sub_category
    , 'Fee Revenue / Transaction' AS metric_name
    , ROUND(IF(gross_transactions > 0, ((fee_revenue*1.0000000)/(gross_transactions*1.0000000)), 0), 4) AS metric_value
FROM (
    SELECT
        year_month_day AS year_month_day
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        , product_pl
        , region
        /* ------------------------------------------------------------------------------------------------------- -- */
        , COUNT(DISTINCT transaction_order_id) AS gross_transactions
        , IF(((product_pl IS NULL AND region IS NULL) OR (product_pl = 'UK' AND region = 'United Kingdom')), SUM(fee_revenue_gbp), SUM(fee_revenue_eur)) AS fee_revenue
    FROM (
        {{ fm_products_extract() }}
    ) fm_products_raw_extract
    GROUP BY CUBE ( year_month_day, product_pl, region )
)
/* -- Script Name = 011_fee_revenue_per_trx.sql :: END -- */
{%- endmacro -%}