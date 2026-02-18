{% test reconcile_incremental_gross_sales_summary(model) %}
WITH am AS (
            SELECT week_commencing_date,
                    region,
                    product_pl,
                    sum(metric_value) metric_value
            FROM   {{ model }} --"stg_data_metrics_layer"."acquisition_mart"
            WHERE 1=1
            AND week_commencing_date BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND date_scope = 'WEEK'
            AND metric_name = 'Incremental Gross Sales'
            AND category='All'
            AND sub_category='All'
            GROUP BY 1,2,3
),
mm as (
    select week_commencing_date
           ,region
           ,product_pl
           ,IF((product_pl IS NULL OR product_pl = 'UK'), incremental_gross_sales_gbp, incremental_gross_sales_eur) AS value
    FROM
        (select week_commencing_date
                ,rm.output_region as region
                ,rm.output_product_pl as product_pl
                ,SUM( IF(kpi IN ('Incremental Gross Sales EUR'), value)) AS incremental_gross_sales_eur
                ,SUM( IF(kpi IN ('Incremental Gross Sales GBP'), value)) AS incremental_gross_sales_gbp
            from  {{ source("bi_dwh", "marketing_mart") }}
            INNER JOIN {{ source("data_metrics_layer", "product_pl_region_map") }} rm
            ON (coalesce(pnl_segment,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
            INNER JOIN {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
            ON (date(activity_date) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
            WHERE 1=1
            AND date(week_commencing_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND    kpi in ('Incremental Gross Sales EUR', 'Incremental Gross Sales GBP')
            AND channel NOT IN ('TOC','Brand')
            group by 1,2,3
           )
)
SELECT *
FROM   mm
LEFT JOIN am
ON mm.region = am.region
AND mm.product_pl = am.product_pl
AND mm.week_commencing_date = am.week_commencing_date
WHERE (abs(cast(am.metric_value as bigint) - cast(mm.value as bigint)) > 1
    OR am.metric_value is null)
AND mm.value > 0
{% endtest %}