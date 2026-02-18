{%- macro non_fee_revenue_per_visit() -%}
/* -- Script Name = 012_non_fee_revenue_per_visit.sql :: BEGIN -- */
SELECT
    year_month_day
    , product_pl
    , region
    , 'All' AS category
    , 'All' AS sub_category
    , 'Non-Fee Revenue / Visit' AS metric_name
    , IF(total_visits > 0, ((non_fee_revenue*1.0000000)/(total_visits*1.0000000)), 0) AS metric_value
FROM (
    SELECT
        fmp.year_month_day AS year_month_day
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        , fmp.product_pl
        , fmp.region
        /* ------------------------------------------------------------------------------------------------------- -- */
        , IF(((fmp.product_pl IS NULL AND fmp.region IS NULL) OR (fmp.product_pl = 'UK' AND fmp.region = 'United Kingdom')), SUM(fmp.non_fee_revenue_gbp), SUM(fmp.non_fee_revenue_eur)) AS non_fee_revenue
        , sum(mkt.total_visits) as total_visits
    FROM ( {{ fm_products_extract() }} ) fmp
    INNER JOIN ( {{ marketing_mart_extract() }} ) mkt
        ON fmp.year_month_day = mkt.year_month_day
        AND fmp.product_pl = mkt.product_pl
        AND fmp.region = mkt.region
    GROUP BY CUBE ( fmp.year_month_day, fmp.product_pl, fmp.region )
)
/* -- Script Name = 012_non_fee_revenue_per_visit.sql :: END -- */
{%- endmacro -%}