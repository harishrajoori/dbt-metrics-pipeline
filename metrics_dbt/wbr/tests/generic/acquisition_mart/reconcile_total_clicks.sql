{% test reconcile_total_clicks(model) %}
with am as (
select year_month_day, metric_name , metric_value, region, category, sub_category, product_pl
from   {{ model }} --"stg_data_metrics_layer"."acquisition_mart"
where  1=1
and    year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
and    date_scope = 'DAY'
GROUP BY year_month_day, metric_name, metric_value, region, category, sub_category,  product_pl
),
mm as (
select activity_date
        ,      CASE
               WHEN kpi LIKE '%Spend%' THEN 'Investment'
               WHEN kpi IN ('Impressions', 'Installs') THEN 'Reach'
               WHEN kpi IN ('Clicks') THEN 'Competition'
               WHEN kpi IN ('Sales', 'Incremental Gross Sales EUR', 'Incremental Gross Sales GBP', 'Incremental Gross Sales') THEN 'Quality'
               WHEN kpi IN ('New Customers', 'Incremental New Customers') THEN 'Traffic'
               END AS category
{#        ,      CASE#}
{#               WHEN COALESCE(channel, 'Unknown') in ('Cross Network', 'App') THEN 'Paid App'#}
{#               WHEN COALESCE(channel, 'Unknown') = 'Paid Search' THEN 'PPC'#}
{#               WHEN COALESCE(channel, 'Unknown') IN ('Affiliates', 'Social', 'Display', 'Paid Display', 'Paid Social') THEN 'Other Paid'#}
{#               WHEN COALESCE(channel, 'Unknown') IN ('Offline Brand', 'Brand') then 'Brand'#}
{#               END AS sub_category#}
        ,      CASE
               WHEN ( lower(device) = 'app' OR lower(channel) = 'app')  and  (sub_channel IN ('Apple Search', 'Google', 'Google UAC')
                     OR channel_source IN ('apple_search', 'adwords'))
                          THEN 'Paid App Lower Funnel'
               WHEN (device = 'app' OR channel = 'App') and (coalesce(sub_channel, 'Unknown') NOT  IN ('Apple Search', 'Google', 'Google UAC')
                    AND coalesce(channel_source, 'Unknown') NOT IN ('apple_search', 'adwords'))
                          THEN 'Paid App Mid Funnel'
               WHEN channel = 'Paid Search'
                          THEN 'Web Lower Funnel'
               WHEN channel IN ('Paid Display','Paid Social', 'Display','Social')
                          THEN 'Web Mid Funnel'
               WHEN channel = 'Affiliates'
                          THEN 'Other Paid'
                WHEN channel = 'Brand'
                          THEN 'Brand'
               ELSE 'Other'
               END sub_category
  ,      case
            when kpi in ('Spend', 'Brand Spend') then 'Marketing Spend'
            when kpi in ('Spend GBP', 'Brand Spend GBP') then 'Marketing Spend GBP'
            when kpi in ( 'Spend EUR', 'Brand Spend EUR') then 'Marketing Spend EUR'
            when kpi = 'Clicks' then 'Total Clicks'
            when kpi = 'Impressions' then 'Total Impressions'
            when kpi = 'New Customers' then 'New Customers'
            when kpi = 'Sales' then 'Gross Sales'
            when kpi = 'Installs' then 'Total Installs'
            when kpi = 'Incremental New Customers' then 'Incremental New Customers'
            else kpi
        end as kpi
,  CASE WHEN pnl_segment = 'INT' THEN 'EU' ELSE pnl_segment END AS product_pl,  CASE
               WHEN (pnl_segment = 'INT' AND region = 'United Kingdom') THEN 'UK>EU'
               WHEN (pnl_segment = 'INT' AND region = 'Unknown') THEN 'France'
               WHEN (pnl_segment = 'UK') THEN 'United Kingdom'
               ELSE region
               END  AS region,
               sum(value) value
from  {{ source("bi_dwh", "marketing_mart") }}
where 1=1
AND    date(activity_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
AND    kpi in ('Spend', 'Spend GBP', 'Spend EUR', 'Clicks', 'Impressions', 'New Customers', 'Sales',
                      'Installs','Brand Spend','Brand Spend EUR','Brand Spend GBP',
                      'Incremental New Customers', 'Incremental Gross Sales EUR', 'Incremental Gross Sales GBP',
                      'Incremental Spend EUR')
AND    channel in ('App', 'Paid Search', 'Affiliates', 'Social', 'Display', 'Brand',
                   'Offline Brand', 'Cross Network', 'Paid Display', 'Paid Search', 'Paid Social'
                    )
group by 1,2,3,4, 5, 6
)
select *
from   am
inner join mm
on     mm.kpi = am.metric_name
and    am.region = mm.region
and    am.category = mm.category
and    am.sub_category = mm.sub_category
and    am.year_month_day = cast(mm.activity_date as date)
and    am.product_pl = mm.product_pl
and    cast(am.metric_value as bigint) <> cast(mm.value as bigint)
and    am.metric_name = 'Total Clicks'
{% endtest %}