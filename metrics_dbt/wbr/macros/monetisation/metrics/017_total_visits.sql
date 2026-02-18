{%- macro total_visits() -%}
/* -- Script Name = 017_total_visits.sql :: BEGIN -- */
SELECT
    year_month_day
    , product_pl
    , region
    , 'All' AS category
    , 'All' AS sub_category
    , 'Total Visits' AS metric_name
    , total_visits AS metric_value
FROM (
    SELECT
        year_month_day
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        , product_pl
        , region
        /* ------------------------------------------------------------------------------------------------------- -- */
        , SUM(total_visits) AS total_visits
    FROM ( {{ marketing_mart_extract() }} ) marketing_mart_raw_extract
    GROUP BY CUBE ( year_month_day, product_pl, region )
)
/* -- Script Name = 017_total_visits.sql :: END -- */
{%- endmacro -%}