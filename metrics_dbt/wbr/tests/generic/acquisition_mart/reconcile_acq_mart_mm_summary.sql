{% test reconcile_acq_mart_mm_summary(model) %}
WITH am AS (
            SELECT week_commencing_date,
                    region,
                    metric_name ,
                    sum(metric_value) metric_value
            FROM   {{ model }} --"stg_data_metrics_layer"."acquisition_mart"
            WHERE 1=1
            AND week_commencing_date BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND date_scope = 'DAY'
            AND category='All'
            AND sub_category='All'
            GROUP BY 1,2,3
),
mm AS (
    SELECT week_commencing_date
        ,CASE
            when kpi = 'Clicks' then 'Total Clicks'
            when kpi = 'Impressions' then 'Total Impressions'
            when kpi = 'Installs' then 'Total Installs'
            when kpi = 'Visits' then 'Total Visits'
            when kpi = 'Incremental New Customers' then 'Incremental New Customers'
            when kpi = 'Incremental Spend EUR' then 'Incremental Spend EUR'
        end as kpi
        ,rm.output_region as region
        ,sum(value) value
    FROM  {{ source("bi_dwh", "marketing_mart") }}
    INNER JOIN {{ source("data_metrics_layer", "product_pl_region_map") }} rm
    ON (coalesce(pnl_segment,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
    INNER JOIN {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
    ON (date(activity_date) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
    WHERE 1=1
    AND date(week_commencing_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
    AND kpi in ('Clicks', 'Impressions','Visits', 'Installs', 'Incremental New Customers', 'Incremental Spend EUR')
    AND channel NOT IN ('TOC','Brand')
    GROUP BY 1,2,3
)
SELECT *
FROM   mm
LEFT JOIN am
ON mm.kpi = am.metric_name
AND mm.region = am.region
AND mm.week_commencing_date = am.week_commencing_date
WHERE (abs(cast(am.metric_value as bigint) - cast(mm.value as bigint)) > 1
    OR am.metric_value is null)
AND mm.value > 0
{% endtest %}