{% test reconcile_booking_dot_com_ctr(model) %}

with booking_dot_com_ctr as (
    SELECT
        DATE(event_date) AS year_month_day
        , country.product_pl AS product_pl
        , country.region AS region
        , event_params_kv_event_action
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

, total_ctr as (
    select
        year_month_day
        , product_pl
        , region
        , Round(CAST(COUNT(DISTINCT product_selected_event) AS DOUBLE) / CAST(COUNT(DISTINCT product_impression_event) AS DOUBLE), 4) AS  metric_value
    from booking_dot_com_ctr
    group by year_month_day, product_pl, region
)

, monetisation_mart_ctr as (
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
    and metric_name = 'CTR'
    and date_scope = 'DAY'
    and year_month_day BETWEEN DATE_ADD('day', -1, date('{{ env_var("exe_start_date") }}')) AND DATE('{{ env_var("exe_end_date") }}')
)

, compare_cte AS (
    SELECT
        mm.year_month_day
        , mm.product_pl
        , mm.region
        , mm.category
        , mm.sub_category
        , mm.metric_name
        , mm.metric_value as mm_metric_value
        , ctr.metric_value as ctr_metric_value
        , ABS(ctr.metric_value - mm.metric_value) AS difference
    FROM total_ctr ctr
    INNER JOIN monetisation_mart_ctr mm
    ON ctr.year_month_day = mm.year_month_day
    AND ctr.product_pl = mm.product_pl
    AND ctr.region = mm.region
)

SELECT *
FROM compare_cte
WHERE difference > 0.0001

{% endtest %}