{%- macro gross_transactions() -%}
/* -- Script Name = 016_gross_transactions.sql :: BEGIN -- */
SELECT
    year_month_day
    , product_pl
    , region
    , 'All' AS category
    , 'All' AS sub_category
    , 'Gross Transactions' AS metric_name
    , gross_transactions AS metric_value
FROM (
    SELECT
        year_month_day AS year_month_day
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        , product_pl
        , region
        /* ------------------------------------------------------------------------------------------------------- -- */
        , COUNT(DISTINCT transaction_order_id) AS gross_transactions
    FROM (
        {{ fm_products_extract() }}
    ) fm_products_raw_extract
    GROUP BY CUBE ( year_month_day, product_pl, region )
)
/* -- Script Name = 016_gross_transactions.sql :: END -- */
{%- endmacro -%}