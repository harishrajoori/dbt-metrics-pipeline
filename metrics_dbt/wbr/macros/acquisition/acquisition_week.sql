{%- macro acquisition_week() -%}
/* -- Script Name = acquisition_week.sql :: BEGIN -- */
WITH
    /* ---
    below CTE extracts all the year_month_day dates which correspond
    to the week_commencing_dates that fall between the start and end dates
    --- */
    calendar_data AS
    (
        SELECT
            week_commencing_date,
            year_month_day
        FROM
            {{ source("data_metrics_layer", "calendar_dates_lookup") }}
        WHERE
            date_scope = 'DAY'
            AND week_commencing_date IN
            (
                SELECT DISTINCT week_commencing_date
                FROM {{ this }}
                WHERE date_scope = 'DAY'
                AND date(year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            )
    ),
    /* ---
    below CTE generates WEEK level aggregations for other (non-customer) metrics
    --- */
    week_aggregation_others AS
    (
        SELECT
            week_commencing_date,
            product_pl,
            region,
            category,
            sub_category,
            metric_name,
            SUM(metric_value) AS metric_value
        FROM {{ this }}
        WHERE date_scope = 'DAY'
        AND week_commencing_date IN
        (
            SELECT DISTINCT week_commencing_date
            FROM {{ this }}
            WHERE date_scope = 'DAY'
            AND date(year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
        )
        GROUP BY 1,2,3,4,5,6
    )
,
acq_data AS (
SELECT
    'WEEK' AS date_scope, calendar.financial_year AS financial_year, calendar.week_number AS week_number, acquisition.week_commencing_date AS year_month_day, CAST (current_time AS timestamp) AS last_modified,
    acquisition.week_commencing_date AS week_commencing_date, acquisition.product_pl AS product_pl, acquisition.region AS region, acquisition.category AS category, acquisition.sub_category AS sub_category,
    acquisition.metric_name AS metric_name, acquisition.metric_value AS metric_value
FROM
    (
    SELECT
    week_commencing_date, product_pl, region, category, sub_category, metric_name, metric_value
    FROM
    week_aggregation_others
    WHERE metric_name IN ('Marketing Spend', 'Total Clicks', 'Total Impressions', 'Total Installs', 'Total Visits',
                          'Incremental New Customers', 'Incremental Gross Sales', 'Payback Months', 'Last Click New Customers',
                          'Last Click Total Transactions','Last Click Transactions Tracked','Last Click Net Sales',
                          'Last Click Marketing Spend','Last Click Gross Sales', 'Total Revenue', 'Total Costs',
                          'Gross Margin', 'GM - PMS' )
    UNION ALL
    select *
    from (
            select t1.week_commencing_date, t1.product_pl, t1.region, t1.category,
                    t1.sub_category, t2.metric_name, t2.metric_value
            from (
                    select week_commencing_date, product_pl, region, category, sub_category,
                            IF(incremental_spend_eur > 0,
                            ((incremental_gross_sales_eur * 1.0000000) / (incremental_spend_eur * 1.0000000)), 0) as incremental_roas,
                            IF(lc_nc > 0 , ( spend / lc_nc)) as cost_per_acquisition,
                            IF(visits > 0 , ( trx_tracked / visits )) as conversion_rate,
                            IF(lc_nc > 0 , ( lc_spend / lc_nc)) as cost_per_acquisition_lc
                    from
                        (
                            select week_commencing_date, product_pl, region, category,
                                    sub_category, coalesce (element_at(key, 'Incremental Gross Sales EUR'), 0) AS incremental_gross_sales_eur,
                                    coalesce (element_at(key, 'Incremental Spend EUR'), 0) AS incremental_spend_eur,
                                    coalesce(element_at(key, 'Last Click Marketing Spend'), 0) AS lc_spend,
                                    coalesce(element_at(key, 'Marketing Spend'), 0) AS spend,
                                    coalesce(element_at(key, 'Last Click Transactions Tracked'), 0) AS trx_tracked,
                                    coalesce(element_at(key, 'Last Click New Customers'), 0) AS lc_nc,
                                    coalesce(element_at(key, 'Total Visits'), 0) AS visits
                            FROM (
                                    SELECT week_commencing_date, product_pl, region, category, sub_category,
                                            map_agg(metric_name, metric_value) key
                                    FROM week_aggregation_others
                                    where metric_name in ('Incremental Gross Sales EUR',
                                                          'Incremental Spend EUR',
                                                          'Last Click Marketing Spend',
                                                          'Marketing Spend',
                                                          'Last Click Transactions Tracked',
                                                          'Total Visits',
                                                          'Last Click New Customers')
                                    GROUP BY week_commencing_date, product_pl, region, category, sub_category
                                 )
                        )
                ) t1
    CROSS JOIN unnest (
    array['Incremental ROAS','CPA','CVR','LC_CPA'],
    array[incremental_roas,cost_per_acquisition,conversion_rate,cost_per_acquisition_lc]
    ) t2 (metric_name, metric_value)
    )
    where coalesce (metric_value, 0) <> 0

    ) acquisition
    INNER JOIN
    {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
ON (date (acquisition.week_commencing_date) = date (calendar.week_commencing_date) AND calendar.date_scope = 'WEEK')
WHERE
    (
    acquisition.week_commencing_date IS NOT NULL
  AND
    acquisition.category IS NOT NULL
  AND
    acquisition.sub_category IS NOT NULL
    )
    ),
    acq_week as 
    (
        SELECT  distinct
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
        FROM    acq_data
        UNION
        SELECT  distinct
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
        FROM    ( {{ customer_metrics_week() }} )
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    acq_week
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
/* -- Script Name = acquisition_week.sql :: END -- */
{%- endmacro -%}