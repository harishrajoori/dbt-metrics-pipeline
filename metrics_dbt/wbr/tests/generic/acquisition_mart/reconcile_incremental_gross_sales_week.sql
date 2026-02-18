{% test reconcile_incremental_gross_sales_week(model) %}
WITH am AS (
            SELECT week_commencing_date,
                    region,
                    product_pl,
                    category,
                    sub_category,
                    sum(metric_value) metric_value
            FROM   {{ model }} --"stg_data_metrics_layer"."acquisition_mart"
            WHERE 1=1
            AND week_commencing_date BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND date_scope = 'WEEK'
            AND metric_name = 'Incremental Gross Sales'
            GROUP BY 1,2,3,4,5
),
mm as (
    select week_commencing_date
           ,category
           ,sub_category
           ,region
           ,product_pl
           ,IF((product_pl IS NULL OR product_pl = 'UK'), sum(incremental_gross_sales_gbp), sum(incremental_gross_sales_eur)) AS value
    FROM
        (select week_commencing_date
                ,year_month_day
                ,'Paid Incremental' AS category
                ,CASE
                   WHEN channel = 'Organic Search' THEN sub_channel
                   WHEN channel IN ('Web - Paid Search','Web - Paid Social','App - Paid Search','App - Paid Social',
                                      'App Organic','Web Direct','Affiliates')
                        THEN channel
                   WHEN channel IN ('Email','Other','Paid Display','Referral') THEN 'Paid Other'
                   ELSE 'Other'
                   END sub_category
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
            group by 1,2,3,4,5,6
           )
           where (incremental_gross_sales_eur > 0 or incremental_gross_sales_gbp > 0)
    group by 1,2,3,4,5
)
SELECT *
FROM   mm
LEFT JOIN am
ON mm.region = am.region
AND mm.product_pl = am.product_pl
AND mm.week_commencing_date = am.week_commencing_date
AND am.category = mm.category
AND am.sub_category = mm.sub_category
WHERE (abs(cast(am.metric_value as bigint) - cast(mm.value as bigint)) > 1
    OR am.metric_value is null)
AND mm.value > 0
{% endtest %}