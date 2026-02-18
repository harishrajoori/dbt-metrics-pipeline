{%- macro wbr_metrics() -%}
/* -- Script Name = 011_wbr_metrics.sql :: BEGIN -- */
SELECT
    year_month_day
    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
    , product_pl
    , region
    /* ------------------------------------------------------------------------------------------------------- -- */
    , 'All' AS category
    , 'All' AS sub_category
    , metric_name
    ,ROUND(
        CASE
            WHEN metric_name = 'Total Revenue' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(total_revenue_gbp), SUM(total_revenue_eur))
            WHEN metric_name = 'Fee Revenue' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(fee_revenue_gbp), SUM(fee_revenue_eur))
            WHEN metric_name = 'Non-Fee Revenue' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(non_fee_revenue_gbp), SUM(non_fee_revenue_gbp))
            WHEN metric_name = 'Gross Transactions' THEN SUM(transaction_order_id_count)
            WHEN metric_name = 'Fee Revenue / Transaction' THEN
                IF( product_pl = 'UK' OR product_pl IS NULL,
                    SUM(CAST(fee_revenue_gbp AS DOUBLE)) / SUM(cast(transaction_order_id_count AS DOUBLE)),
                    SUM(CAST(fee_revenue_eur AS DOUBLE)) / SUM(cast(transaction_order_id_count AS DOUBLE))
                )
        END, 4) AS metric_value
FROM ( {{ fm_products_extract() }} ) fm_products_raw_extract
CROSS JOIN UNNEST(
        ARRAY[ 'Fee Revenue / Transaction', 'Total Revenue', 'Fee Revenue', 'Non-Fee Revenue', 'Gross Transactions' ]
    ) AS t(metric_name)
GROUP BY CUBE(year_month_day, product_pl, region, metric_name)
/* -- Script Name = 011_wbr_metrics.sql :: END -- */
{%- endmacro -%}