{% test reconcile_total_clicks_summary(model) %}
with acm as (
select year_month_day, metric_name , region, product_pl, sum(metric_value) metric_value
from   {{ model }} --"stg_data_metrics_layer"."acquisition_mart"
where  1=1
and    year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
and    date_scope = 'DAY'
and    category ='All'
and    sub_category ='All'
group by 1,2,3,4
)
,
mm
as
(
select activity_date
,      case when kpi in ('Spend','Brand Spend')  then 'Marketing Spend'
            when kpi in ('Spend GBP', 'Brand Spend GBP')then 'Marketing Spend GBP'
            when kpi in ('Spend EUR', 'Brand Spend EUR') then 'Marketing Spend EUR'
            when kpi = 'Clicks' then 'Total Clicks'
            when kpi =  'Impressions' then 'Total Impressions'
            when kpi = 'New Customers' then 'New Customers'
            when kpi ='Sales' then 'Gross Sales'
            when kpi = 'Installs' then 'Total Installs'
            else kpi END AS kpi
,    CASE
               WHEN (pnl_segment = 'INT' AND region = 'United Kingdom') THEN 'UK>EU'
               WHEN (pnl_segment = 'INT' AND region = 'Unknown') THEN 'France'
               WHEN (pnl_segment = 'UK') THEN 'United Kingdom'
               ELSE region
               END  AS region
,    CASE WHEN pnl_segment = 'INT' THEN 'EU' ELSE pnl_segment END AS product_pl
,    sum(value) as value
from  {{ source("bi_dwh", "marketing_mart") }}
where 1=1
AND    date(activity_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
AND    channel in ('App', 'Paid Search', 'Affiliates', 'Social', 'Display', 'Brand',
                   'Offline Brand', 'Cross Network', 'Paid Display', 'Paid Search', 'Paid Social'
                    )
group by 1,2,3,4
)
select *
from   acm am
inner join mm
on     mm.kpi = am.metric_name
and    am.region = mm.region
and    am.year_month_day = cast(mm.activity_date as date)
and    am.product_pl = mm.product_pl
and    cast(am.metric_value as bigint) <> cast(mm.value as bigint)
and    am.metric_name = 'Total Clicks'
{% endtest %}