{% test reconcile_acq_mart_mm_week(model) %}
WITH am AS (
            SELECT week_commencing_date,
                    region,
                    product_pl,
                    category,
                    sub_category,
                    metric_name ,
                    sum(metric_value) metric_value
            FROM   {{ model }} --"stg_data_metrics_layer"."acquisition_mart"
            WHERE 1=1
            AND week_commencing_date BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND date_scope = 'WEEK'
            GROUP BY 1,2,3,4,5,6
),
mm AS (
    SELECT  week_commencing_date,
            category,
            sub_category,
            kpi,
            region,
            product_pl,
            sum(value) value
    FROM
    (
    SELECT week_commencing_date
        ,year_month_day
        ,CASE
           WHEN kpi IN ('Incremental New Customers') THEN 'Paid Incremental'
           WHEN kpi NOT IN  ('Installs','Clicks')
                AND channel = 'Organic Search' THEN 'Organic'
           WHEN kpi IN ('Impressions', 'Visits') THEN 'Last Click'
           ELSE 'Other'
           END AS category

        ,CASE
                /* -- As part of New Channel mapping, channel values changed in MM logic --------------------------------------- -- */
               WHEN kpi NOT IN ('Installs','New Customers','Clicks','Sales')
                    AND channel = 'Organic Search' THEN sub_channel
               WHEN channel IN ('Web - Paid Search','Web - Paid Social','App - Paid Search','App - Paid Social',
                                  'App Organic','Web Direct','Affiliates')
                    THEN channel
               WHEN channel IN ('Email','Other','Paid Display','Referral') THEN 'Paid Other'
                /* ------------------------------------------------------------------------------------------------------- -- */

               WHEN ( lower(device) = 'app' OR lower(channel) = 'app')  and  (sub_channel IN ('Apple Search', 'Google', 'Google UAC')
                     OR channel_source IN ('apple_search', 'adwords'))
                          THEN 'Paid App Lower Funnel'
               WHEN (lower(device) = 'app' OR lower(channel) = 'app') and (coalesce(sub_channel, 'Unknown') NOT  IN ('Apple Search', 'Google', 'Google UAC')
                    AND coalesce(channel_source, 'Unknown') NOT IN ('apple_search', 'adwords'))
                          THEN 'Paid App Mid Funnel'
               WHEN kpi = 'Installs' and channel = 'Paid Search' THEN 'Paid App Lower Funnel'
               WHEN kpi = 'Installs' and channel in ('Display', 'Social', 'Paid Display','Paid Social')  THEN 'Paid App Mid Funnel'
               WHEN kpi<> 'Installs' AND channel = 'Paid Search'
                          THEN 'Web Lower Funnel'
               WHEN kpi<> 'Installs' AND channel IN ('Paid Display','Paid Social', 'Display','Social')
                          THEN 'Web Mid Funnel'
               WHEN channel = 'Affiliates'
                          THEN 'Other Paid'
                WHEN channel = 'Brand'
                          THEN 'Brand'
               ELSE 'Other'
               END sub_category
        ,CASE
            when kpi = 'Clicks' then 'Total Clicks'
            when kpi = 'Impressions' then 'Total Impressions'
            when kpi = 'Installs' then 'Total Installs'
            when kpi = 'Visits' then 'Total Visits'
            when kpi = 'Incremental New Customers' then 'Incremental New Customers'
        end as kpi
        ,rm.output_region as region
        ,rm.output_product_pl as product_pl
        ,sum(value) value
    FROM  {{ source("bi_dwh", "marketing_mart") }}
    INNER JOIN {{ source("data_metrics_layer", "product_pl_region_map") }} rm
    ON (coalesce(pnl_segment,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
    INNER JOIN {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
    ON (date(activity_date) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
    WHERE 1=1
    AND date(week_commencing_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
    AND kpi in ('Clicks', 'Impressions','Visits', 'Installs', 'Incremental New Customers')
    AND channel NOT IN ('TOC','Brand')
    GROUP BY 1,2,3,4,5,6,7
    )
    where value > 0
    GROUP BY 1,2,3,4,5,6
)
SELECT *
FROM   mm
LEFT JOIN am
ON mm.kpi = am.metric_name
AND mm.region = am.region
AND mm.product_pl = am.product_pl
AND mm.week_commencing_date = am.week_commencing_date
AND am.category = mm.category
AND am.sub_category = mm.sub_category
WHERE (abs(cast(am.metric_value as bigint) - cast(mm.value as bigint)) > 1
    OR am.metric_value is null)
AND mm.value > 0
{% endtest %}