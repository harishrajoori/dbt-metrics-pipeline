{% test reconcile_marketing_spend_week(model) %}
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
            AND metric_name = 'Marketing Spend'
            GROUP BY 1,2,3,4,5
),
mm AS (
    select week_commencing_date
           ,category
           ,sub_category
           ,region
           ,product_pl
           ,IF((product_pl IS NULL OR product_pl = 'UK'), sum(marketing_spend_gbp), sum(marketing_spend_eur)) AS value
    FROM
        (
         SELECT week_commencing_date
            ,year_month_day
            ,CASE
               WHEN channel = 'Organic Search' THEN 'Organic'
               ELSE 'Last Click'
               END AS category
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
            ,SUM( IF(kpi IN ('Spend EUR'), value)) AS marketing_spend_eur
            ,SUM( IF(kpi IN ('Spend GBP'), value)) AS marketing_spend_gbp
        FROM  {{ source("bi_dwh", "marketing_mart") }}
        INNER JOIN {{ source("data_metrics_layer", "product_pl_region_map") }} rm
        ON (coalesce(pnl_segment,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
        INNER JOIN {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
        ON (date(activity_date) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
        WHERE 1=1
        AND date(week_commencing_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
        AND kpi in ('Spend GBP', 'Spend EUR')
        AND channel NOT IN ('TOC','Brand')
        GROUP BY 1,2,3,4,5,6
        )
        where (marketing_spend_gbp > 0 OR marketing_spend_eur > 0)
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