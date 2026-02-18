{%- macro ads_metrics() -%}
/* -- Script Name = 101_ads_metrics.sql :: BEGIN -- */
SELECT
    year_month_day,
    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
    rm.output_product_pl as product_pl,
    rm.output_region as region,
    /* ------------------------------------------------------------------------------------------------------- -- */
    'Non Trx' AS category,
    'Ads' AS sub_category,
    metric_name,
    ROUND(
        CASE
            -- Ads Revenue Metrics
            WHEN metric_name = 'Revenue' THEN SUM(CAST(line_item_level_cpm_and_cpc_revenue AS DOUBLE) / 1000000)
            WHEN metric_name = 'Impressions' THEN SUM(line_item_level_impressions)
            WHEN metric_name = 'Monetised Impressions' THEN
                SUM(CASE WHEN LOWER(line_item_name) LIKE '%house%' THEN NULL ELSE line_item_level_impressions END)
            WHEN metric_name = 'Clicks' THEN SUM(line_item_level_clicks)
            WHEN metric_name = 'CTR' THEN
                SUM(CAST(line_item_level_clicks AS DOUBLE)) / SUM(CAST(line_item_level_impressions AS DOUBLE))
            WHEN metric_name = 'CPM' THEN
                ( SUM( CAST( line_item_level_cpm_and_cpc_revenue AS DOUBLE ) / 1000000) /
                    ( SUM(
                        CASE WHEN LOWER(line_item_name) LIKE '%house%' THEN NULL ELSE CAST(line_item_level_impressions AS DOUBLE) END
                        ) / 1000
                    )
                )
        END, 4) AS metric_value
FROM (
        {{ gamperformancereport_extract() }}
    ) gam
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
inner join 
    {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
    on (coalesce(gam.product_pl,'(null)') = rm.input_product_pl and coalesce(gam.region, '(null)') = rm.input_region)
/* ------------------------------------------------------------------------------------------------------- -- */
CROSS JOIN UNNEST(
        ARRAY[ 'Revenue', 'Impressions', 'CTR', 'CPM', 'Clicks', 'Monetised Impressions' ]
    ) AS t(metric_name)
GROUP BY CUBE(year_month_day, rm.output_product_pl, rm.output_region, metric_name)
/* -- Script Name = 101_ads_metrics.sql :: END -- */
{%- endmacro -%}