{% test reconcile_ads_impressions(model) %}

with gam_ads_impressions as (
    SELECT
        DATE(event_date) AS year_month_day
        , 'UK' AS product_pl
        , 'United Kingdom' AS region
        , event_total_line_item_level_impressions as impressions
        , row_number() OVER (PARTITION BY event_order_id, event_programmatic_channel_name, event_advertiser_name, event_creative_id, event_date, event_ad_unit_name, event_device_category_name, event_ad_unit_id, event_mobile_app_name, event_line_item_id, event_order_name, event_advertiser_id, event_device_category_id, event_mobile_inventory_type, event_country_criteria_id, event_country_name, event_line_item_type ORDER BY header_eventtime DESC) rn
    FROM data_lake_private_prod.gamperformancereport
    WHERE DATE(event_date) BETWEEN DATE_ADD('day', -1, date('{{ env_var("exe_start_date") }}')) AND date('{{ env_var("exe_end_date") }}')
    AND LOWER(event_advertiser_name) != 'intowownonbillable'
)

, total_gam_ads_impressions as (
    select
        year_month_day
        , sum(impressions) as metric_value
    from gam_ads_impressions
    where rn = 1
    group by year_month_day
)

, monetisation_mart_ads_impressions as (
    select
        year_month_day
        , category
        , sub_category
        , metric_name
        , metric_value
    from {{ model }}
    where category = 'Non Trx'
    and sub_category = 'Ads'
    and metric_name = 'Impressions'
    and date_scope = 'DAY'
    and year_month_day BETWEEN DATE_ADD('day', -1, date('{{ env_var("exe_start_date") }}')) AND date('{{ env_var("exe_end_date") }}')
)

, compare_cte AS (
    SELECT
        mm.year_month_day
        , category
        , sub_category
        , metric_name
        , mm.metric_value as mm_metric_value
        , gam.metric_value as gam_metric_value
        , ABS(gam.metric_value - mm.metric_value) AS difference
    FROM total_gam_ads_impressions gam
    INNER JOIN monetisation_mart_ads_impressions mm
    ON gam.year_month_day = mm.year_month_day
)

SELECT *
FROM compare_cte
WHERE difference > 0.001
{% endtest %}