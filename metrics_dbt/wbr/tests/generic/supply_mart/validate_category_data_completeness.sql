{% test validate_category_data_completeness(model) %}

{{ config(severity = 'error') }}

with
    target_dataset as
    (
        select *
        from {{ model }} --"{env}_data_metrics_layer"."supply_mart"
        where year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
        and date_scope = 'DAY'
    ),
    percent_calculation as
    (
        select sum(case when category is null then 1 else 0 end) as null_count, count(*) as record_count
        from target_dataset
    )
select 1
from percent_calculation
where ((null_count*1.00)/(record_count*1.00)) > 0.10

{% endtest %}