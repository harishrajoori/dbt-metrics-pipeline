{%- macro partnership_booking_dot_com_ga_metrics() -%}
/* -- Script Name = 203_partnership_booking_dot_com_ga_metrics.sql :: BEGIN -- */
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select 
    year_month_day as year_month_day,
    map.output_product_pl as product_pl,
    map.output_region as region,
    category as category,
    sub_category as sub_category,
    metric_name as metric_name,
    sum(metric_value) as metric_value
from    
( 
/* ------------------------------------------------------------------------------------------------------- -- */
    SELECT DISTINCT
        year_month_day
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        , product_pl
        , region
        /* ------------------------------------------------------------------------------------------------------- -- */
        , 'Non Trx' AS category
        , 'Partnerships-booking.com' AS sub_category
        , metric_name
        , ROUND(
            CASE
                WHEN metric_name = 'Impressions' THEN SUM(product_impression_event_count)
                WHEN metric_name = 'Clicks' THEN SUM(product_selected_event_count)
                WHEN metric_name = 'CTR' THEN
                    CAST(SUM(product_selected_event_count) AS DOUBLE) / CAST(SUM(product_impression_event_count) AS DOUBLE)
            END, 4) AS metric_value
    FROM (
        select
            year_month_day
            , product_pl
            , region
            , COUNT(DISTINCT product_selected_event) as product_selected_event_count
            , COUNT(DISTINCT product_impression_event) as product_impression_event_count
        from (
            SELECT
                DATE(event_date) AS year_month_day
                , country.product_pl AS product_pl
                , country.region AS region
                , CASE WHEN event_params_kv_event_action = 'product selected' THEN event_id END as product_selected_event
                , CASE WHEN event_params_kv_event_action = 'product impression' THEN event_id END as product_impression_event
            FROM de_ga4_events.events_enriched_details ga
            LEFT JOIN {{ source("data_metrics_layer", "country_codes_lookup") }} country
                ON lower(ga.geo_country) = lower(country.country_name)
            WHERE
                date(event_date) BETWEEN DATE_ADD('day', -1, date('{{ env_var("exe_start_date") }}')) AND date('{{ env_var("exe_end_date") }}')
                AND event_params_kv_event_category = 'partnership'
                AND event_params_kv_event_action in ('product impression','product selected')
                AND event_params_kv_event_label = 'accommodation'
                -- Skiped some weeks of data due to issue
                AND NOT (DATE(event_date) BETWEEN DATE('2024-09-15') AND DATE('2024-10-12'))
        )
        group by year_month_day, product_pl, region
    )
    CROSS JOIN UNNEST(
            ARRAY['Impressions', 'CTR', 'Clicks']
        ) AS t(metric_name)
    GROUP BY CUBE(year_month_day, product_pl, region, metric_name)
) qry 
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
inner join 
    {{ source("data_metrics_layer", "product_pl_region_map") }} map 
    on ((qry.product_pl = map.input_product_pl) and (qry.region = map.input_region))
where 
    qry.year_month_day is not null
    and qry.product_pl is not null
    and qry.region is not null
group by 
    1,2,3,4,5,6
/* ------------------------------------------------------------------------------------------------------- -- */
/* -- Script Name = 203_partnership_booking_dot_com_ga_metrics.sql :: END -- */
{%- endmacro -%}