{%- macro monetisation_day() -%}
/* -- Script Name = monetisation_day.sql :: BEGIN -- */
with monetisation_metrics as (
    {{ monetisation_metrics() }}
),
mnt_day as 
(
    SELECT DISTINCT
        'DAY' AS date_scope,
        calendar.financial_year AS financial_year,
        calendar.week_number AS week_number,
        monetisation.year_month_day AS year_month_day,
        CAST(current_time AS timestamp) AS last_modified,
        calendar.week_commencing_date AS week_commencing_date,
        monetisation.product_pl AS product_pl,
        monetisation.region AS region,
        monetisation.category AS category,
        monetisation.sub_category AS sub_category,
        monetisation.metric_name AS metric_name,
        monetisation.metric_value AS metric_value
    FROM monetisation_metrics monetisation
    INNER JOIN {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
        ON (date(monetisation.year_month_day) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
)
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    mnt_day 
where 
/* -- filtering out unrequired records -- */
(
  financial_year is not null 
  and 
  week_number is not null 
  and 
  year_month_day is not null
  and 
  week_commencing_date is not null 
  and
  product_pl is not null
  and 
  region is not null 
  and 
  category is not null
  and 
  sub_category is not null
  and 
  metric_name is not null
  and 
  metric_value is not null
)
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
/* -- Script Name = monetisation_day.sql :: END -- */
{%- endmacro -%}