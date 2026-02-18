{%- macro ads_quality() -%}
/* -- Script Name = 104_ads_quality.sql :: BEGIN -- */
SELECT DISTINCT
    year_month_day
    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
    , rm.output_product_pl as product_pl
    , rm.output_region as region
    /* ------------------------------------------------------------------------------------------------------- -- */
    , 'Non Trx' AS category
    , 'Ads' AS sub_category
    , 'CPM' AS metric_name
    , ROUND(( SUM( CAST( event_total_line_item_level_cpm_and_cpc_revenue AS DOUBLE ) / 1000000) /
        ( SUM(
            CASE WHEN LOWER(event_line_item_name) LIKE '%house%' THEN NULL ELSE CAST(event_total_line_item_level_impressions AS DOUBLE) END
            ) / 1000
        )
    ), 4) as metric_value
FROM (
    SELECT
        DATE(event_date) AS year_month_day
        , 'UK' AS product_pl
        , 'United Kingdom' AS region
        , event_total_line_item_level_cpm_and_cpc_revenue
        , event_line_item_name
        , event_total_line_item_level_impressions
        , ROW_NUMBER() OVER (PARTITION BY event_order_id, event_programmatic_channel_name, event_advertiser_name, event_creative_id, event_date, event_ad_unit_name, event_device_category_name, event_ad_unit_id, event_mobile_app_name, event_line_item_id, event_order_name, event_advertiser_id, event_device_category_id, event_mobile_inventory_type, event_country_criteria_id, event_country_name, event_line_item_type ORDER BY header_eventtime DESC) rn
    FROM data_lake_private_prod.gamperformancereport
    WHERE DATE(event_date) BETWEEN DATE('{{ env_var("exe_start_date") }}') AND DATE('{{ env_var("exe_end_date") }}')
    AND LOWER(event_advertiser_name) != 'intowownonbillable'
) gam
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
inner join 
    {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
    on (coalesce(gam.product_pl,'(null)') = rm.input_product_pl and coalesce(gam.region, '(null)') = rm.input_region)
/* ------------------------------------------------------------------------------------------------------- -- */
WHERE rn = 1
GROUP BY CUBE(year_month_day, rm.output_product_pl, rm.output_region)
/* -- Script Name = 104_ads_quality.sql :: END -- */
{%- endmacro -%}