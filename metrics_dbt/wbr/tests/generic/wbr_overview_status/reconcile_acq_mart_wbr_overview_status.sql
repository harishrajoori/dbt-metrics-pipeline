{% test reconcile_acq_mart_wbr_overview_status(model) %}
WITH acq_mart
AS
(
select date_scope,
            financial_year,
            week_number,
            year_month_day,
            last_modified,
            week_commencing_date,
            product_pl,
            region,
            category,
            sub_category,
            case when metric_name='Total Visits' then 'Acquisition Visits' else metric_name end as metric_name,
            metric_value
from  {{ source("data_metrics_layer", "acquisition_mart") }}
where UPPER(category) ='ALL'
and   UPPER(sub_category) ='ALL'
and   year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
)
,
wbr
AS
(
select *
from   {{ model }}
where  year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
)
select *
from wbr
left outer join acq_mart
on (wbr.product_pl = acq_mart.product_pl
and wbr.region = acq_mart.region
and wbr.year_month_day = acq_mart.year_month_day
and upper(wbr.metric_name) = upper(acq_mart.metric_name)
and wbr.date_scope = acq_mart.date_scope
)
where cast(wbr.metric_value as bigint) <> cast(acq_mart.metric_value as bigint)
{% endtest %}