{% test reconcile_booking_dot_com_impressions(model) %}

with booking_dot_com_impressions as (
    SELECT
        DATE(event_date) AS year_month_day
        , country.product_pl AS product_pl
        , country.region AS region
        , event_params_kv_event_action
        , event_id
    FROM de_ga4_events.events_enriched_details ga
    LEFT JOIN {{ source("data_metrics_layer", "country_codes_lookup") }} country
        ON LOWER(ga.geo_country) = LOWER(country.country_name)
    WHERE
        date(event_date) BETWEEN DATE_ADD('day', -1, date('{{ env_var("exe_start_date") }}')) AND DATE('{{ env_var("exe_end_date") }}')
        AND event_params_kv_event_category = 'partnership'
        AND event_params_kv_event_action in ('product impression')
        AND event_params_kv_event_label = 'accommodation'
        -- Skiped some weeks of data due to issue
        AND NOT (DATE(event_date) BETWEEN DATE('2024-09-15') AND DATE('2024-10-12'))
)

, total_number_of_impressions as (
    select
        year_month_day
        , product_pl
        , region
        , COUNT(DISTINCT event_id ) AS metric_value
    from booking_dot_com_impressions
    group by year_month_day, product_pl, region
)

, monetisation_mart_impressions as (
    select
        year_month_day
        , product_pl
        , region
        , category
        , sub_category
        , metric_name
        , metric_value
    from {{ model }}
    where category = 'Non Trx'
    and sub_category = 'Partnerships-booking.com'
    and metric_name = 'Impressions'
    and date_scope = 'DAY'
    and year_month_day BETWEEN DATE_ADD('day', -1, date('{{ env_var("exe_start_date") }}')) AND DATE('{{ env_var("exe_end_date") }}')
)

, compare_cte AS (
    SELECT
        mm.year_month_day
        , mm.product_pl
        , mm.region
        , category
        , mm.sub_category
        , mm.metric_name
        , mm.metric_value as mm_metric_value
        , impr.metric_value as impr_metric_value
        , ABS(impr.metric_value - mm.metric_value) AS difference
    FROM total_number_of_impressions impr
    INNER JOIN monetisation_mart_impressions mm
    ON impr.year_month_day = mm.year_month_day
    AND impr.product_pl = mm.product_pl
    AND impr.region = mm.region
)

SELECT *
FROM compare_cte
WHERE difference > 0

{% endtest %}