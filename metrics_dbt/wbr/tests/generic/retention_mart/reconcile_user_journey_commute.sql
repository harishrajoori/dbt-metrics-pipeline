{% test reconcile_user_journey_commute(model) %}

with retention as
(
    select
        year_month_day
        ,product_pl
        ,region
        ,max(case when metric_name = 'Number of Customers' then metric_value end) as customer_count
        ,max(case when metric_name = 'Net Sales Amount' then metric_value end) as net_sales_amount
        ,max(case when metric_name = 'Total number of Orders' then metric_value end) as order_count
    from   {{ model }} --"{env}_data_metrics_layer"."retention_mart"
    where  1=1
    and    year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
    and    date_scope = 'DAY'
    and    sub_category = 'Commute and Regional'
    group by 1,2,3
),

fm_data as
(
    select date(year_month_day) AS year_month_day
           , product_pl_code AS product_pl
           , CASE
               WHEN (product_pl_code = 'EU' AND order_region_name = 'United Kingdom') THEN 'UK>EU'
               WHEN (product_pl_code = 'EU' AND order_region_name = 'Unknown') THEN 'France'
               WHEN (product_pl_code = 'UK') THEN 'United Kingdom'
               ELSE order_region_name
             END AS region
           , count(distinct order_customer_id) as customer_count
           , count(distinct IF(product_gross_sales_flag = 'Y' AND record_type = 'SALES', order_id)) AS order_count
           , round(IF((product_pl_code = 'UK' OR product_pl_code IS NULL), SUM(m_net_sales_amount_gbp), SUM(m_net_sales_amount_eur)), 4) AS net_sales_amount
from  {{ source("bi_dwh", "fm_products") }}
where year_month_day BETWEEN ('{{ env_var("exe_start_date") }}') AND ('{{ env_var("exe_end_date") }}')
    AND order_business_channel_code = '{{ var("retention_mart")["business_channel"] }}'
    AND order_managed_group_id IN {{ var("retention_mart")["managed_group_id"] }}
    AND UPPER(product_type_code) IN {{ var("retention_mart")["product_type_code"] }}
    AND source_system IN {{ var("fm_products")["source_system"] }}
    AND fare_train_classification_name_longest_duration = 'regional'
    AND product_travel_classification_name = 'Commuting'
group by 1,2,3
)

select
    retention.year_month_day
    ,retention.product_pl
    ,retention.region
    ,retention.customer_count as mece_customer_count
    ,fm_data.customer_count as source_customer_count
    ,retention.order_count as mece_order_count
    ,fm_data.order_count as source_order_count
    ,retention.net_sales_amount as mece_net_sales
    ,fm_data.net_sales_amount as source_net_sales
from   retention
inner join fm_data
on     retention.year_month_day = fm_data.year_month_day
and    retention.product_pl = fm_data.product_pl
and    retention.region = fm_data.region
{% if env_var("exe_type") == 'day' %}
where    (retention.customer_count <> fm_data.customer_count
        or retention.order_count <> fm_data.order_count
        or retention.net_sales_amount <> fm_data.net_sales_amount)
{% else %}
where    abs(retention.net_sales_amount - fm_data.net_sales_amount)*100/fm_data.net_sales_amount > 0.2
{% endif %}
{% endtest %}