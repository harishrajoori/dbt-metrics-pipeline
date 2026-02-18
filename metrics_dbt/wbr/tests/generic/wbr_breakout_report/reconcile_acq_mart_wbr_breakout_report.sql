{% test reconcile_acq_mart_wbr_breakout_report(model) %}
WITH acq_mart
AS
(
select *

from   {{ source("data_metrics_layer", "acquisition_mart") }}  -- stg_data_metrics_layer.acquisition_mart
where  year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
)
,
wbr
AS
(
select *
from   {{ model }}    -- stg_data_metrics_layer.wbr_breakout_report
where  metric_mart_name = 'acquisition_mart'
and    year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
)
select *
from wbr
left outer join acq_mart
on (wbr.product_pl = acq_mart.product_pl
and wbr.region = acq_mart.region
and wbr.category = acq_mart.category
and wbr.sub_category = acq_mart.sub_category
and wbr.year_month_day = acq_mart.year_month_day
and upper(wbr.metric_name) = upper(acq_mart.metric_name)
and wbr.date_scope = acq_mart.date_scope
)
where cast(wbr.metric_value as bigint) <> cast(acq_mart.metric_value as bigint)

{% endtest %}