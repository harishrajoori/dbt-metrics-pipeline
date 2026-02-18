{%- macro total_revenue() -%}
/* -- Script Name = 013_total_revenue.sql :: BEGIN -- */
SELECT
    year_month_day
    , product_pl
    , region
    , 'All' AS category
    , 'All' AS sub_category
    , 'Total Revenue' AS metric_name
    , total_revenue AS metric_value
FROM (
    SELECT
        year_month_day AS year_month_day
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        , product_pl
        , region
        /* ------------------------------------------------------------------------------------------------------- -- */
        , IF(((product_pl IS NULL AND region IS NULL) OR (product_pl = 'UK' AND region = 'United Kingdom')), SUM(total_revenue_gbp), SUM(total_revenue_eur)) AS total_revenue
    FROM (
        {{ fm_products_extract() }}
    ) fm_products_raw_extract
    GROUP BY CUBE ( year_month_day, product_pl, region )
)
/* -- Script Name = 013_total_revenue.sql :: END -- */
{%- endmacro -%}