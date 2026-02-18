{%- macro acquisition_day() -%}
/* -- Script Name = acquisition_day.sql :: BEGIN -- */
WITH acquisition_metrics
AS (
     {{ acquisition_metrics() }}
   )
, payback_months as ( {{ payback_months() }} )
, acq_data AS
   (
SELECT
    'DAY' AS date_scope, calendar.financial_year AS financial_year, calendar.week_number AS week_number,
    acquisition.year_month_day AS year_month_day, CAST (current_time AS timestamp) AS last_modified, calendar.week_commencing_date AS week_commencing_date,
    acquisition.product_pl AS product_pl, acquisition.region AS region, acquisition.category AS category, acquisition.sub_category AS sub_category,
    acquisition.metric_name AS metric_name, acquisition.metric_value AS metric_value
FROM (
    SELECT * FROM acquisition_metrics
    union all
    select * from payback_months
    ) acquisition
    INNER JOIN {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
ON (date (acquisition.year_month_day) = date (calendar.year_month_day)
    AND calendar.date_scope = 'DAY')
WHERE
    acquisition.year_month_day IS NOT NULL
    AND
    acquisition.category IS NOT NULL
    AND 
    acquisition.sub_category IS NOT NULL

    ),
    acq_day as 
    (
        SELECT  date_scope,
                financial_year,
                week_number,
                year_month_day,
                last_modified,
                week_commencing_date,
                product_pl,
                region,
                category,
                sub_category,
                metric_name,
                metric_value
        FROM    acq_data
        UNION
        SELECT
            date_scope,
            financial_year,
            week_number,
            year_month_day,
            last_modified,
            week_commencing_date,
            product_pl,
            region,
            category,
            sub_category,
            metric_name,
            metric_value
        FROM ( {{ customer_metrics_day() }} )
        WHERE metric_name IN ('GM - PMS', 'Total Revenue', 'Gross Margin', 'New Customers', 'Active Customers', 'Existing Customers' ,  'Total Costs')
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    acq_day 
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
/* -- Script Name = acquisition_day.sql :: END -- */
{%- endmacro -%}