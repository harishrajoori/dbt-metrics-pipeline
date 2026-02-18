{% test reconcile_growth_accounting_resurrected(model) %}

with retention as
(
    select
        year_month_day
        ,product_pl
        ,region
        ,max(case when metric_name like '%Person Count' then metric_value end) as customer_count
        ,max(case when metric_name like '%NTS Amount' then metric_value end) as net_sales_amount
        ,max(case when metric_name like '%moved to Retained' then metric_value end) as retention_count
        ,max(case when metric_name like '%moved to Churned' then metric_value end) as churned_count
    from   {{ model }} --"{env}_data_metrics_layer"."retention_mart"
    where  1=1
    and    year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
    and    date_scope = upper('{{ env_var("exe_type") }}')
    and    sub_category = 'Resurrected'
    group by 1,2,3
),

growth_summary as
(
    select 
           product_pl AS product_pl
           ,CASE
                 WHEN (product_pl = 'EU' AND region = 'United Kingdom') THEN 'UK>EU'
                 WHEN (product_pl = 'EU' AND region = 'Unknown') THEN 'France'
                 WHEN (product_pl = 'UK') THEN 'United Kingdom'
                 ELSE region
             END AS region
           , CASE upper('{{ env_var("exe_type") }}')
              WHEN 'WEEK' THEN date_add('day', -1, year_month_day)
              ELSE year_month_day
              END AS year_month_day
                 --Resurrected--
           , sum(res_volume) as customer_count
           , round(IF((product_pl = 'UK' OR product_pl IS NULL), sum(res_nts_gbp), sum(res_nts_eur)), 4) AS net_sales_amount
           , sum(res_retention) as retention_count
           , sum(res_churned) as churned_count
FROM {{ source("bi_dwh_users", "growth_accounting_summary") }}
    where date_scope=upper('{{ env_var("exe_type") }}')
    AND date_add('day', -1, year_month_day)
    BETWEEN date_add('day', -1, date('{{ env_var("exe_start_date") }}') )
        AND date('{{ env_var("exe_end_date") }}')
    GROUP BY 1,2,3
)

select
    retention.year_month_day
    ,retention.product_pl
    ,retention.region
    ,retention.customer_count as mece_customer_count
    ,growth_summary.customer_count as source_customer_count
    ,retention.retention_count as mece_retention_count
    ,growth_summary.retention_count as source_retention_count
    ,retention.churned_count as mece_churned_count
    ,growth_summary.churned_count as source_churned_count
    ,retention.net_sales_amount as mece_net_sales
    ,growth_summary.net_sales_amount as source_net_sales
from   retention
inner join growth_summary
on     retention.year_month_day = growth_summary.year_month_day
and    retention.product_pl = growth_summary.product_pl
and    retention.region = growth_summary.region
where    (retention.customer_count <> growth_summary.customer_count
        or retention.retention_count <> growth_summary.retention_count
        or retention.churned_count <> growth_summary.churned_count
        or retention.net_sales_amount <> growth_summary.net_sales_amount)

{% endtest %}