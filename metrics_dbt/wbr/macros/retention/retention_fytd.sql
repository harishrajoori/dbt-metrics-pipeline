-- UPDATED ON 18-Sep-2024 || DQ VERIFIED || CODE REVIEWED

-- DELETE FROM "my_company_data"."stg_wbr_mart"."retention_datamart" WHERE date_scope = 'FYtD';

{%- macro retention_fytd() -%}
/* -- Script Name = retention_fytd.sql :: BEGIN -- */
WITH
    /* ---
    below CTE extracts all the year_month_day dates which correspond
    to the financial_years that fall between the start and end dates
    --- */
    calendar_data AS 
    (
        SELECT
            financial_year,
            week_number,
            week_commencing_date,
            year_month_day
        FROM 
            {{ source("data_metrics_layer", "calendar_dates_lookup") }}
        WHERE 
            date_scope = 'WEEK'
            AND financial_year IN
            (
                SELECT DISTINCT financial_year
                FROM {{ this }}
                WHERE date_scope = 'WEEK'
                AND date(year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            )
    ),
    /* ---
    below CTE is to extract customer and non-customer metric values
    at DAY level from retention_mart
    --- */
    fytd_aggregation_others AS
    (
        SELECT
            DISTINCT
            financial_year,
            week_number,
            year_month_day,
            week_commencing_date,
            product_pl,
            region,
            category,
            sub_category,
            metric_name,
            SUM(metric_value) OVER (PARTITION BY financial_year,product_pl,region,category,sub_category,metric_name ORDER BY week_commencing_date) AS metric_value
        FROM
            {{ this }}
        WHERE
            date_scope = 'WEEK'
            AND metric_name IN ('28d Early life Person Count', '28d Retained Person Count', '28d Resurrected Person Count',
                                '28d Early life Person NTS Amount', '28d Retained Person NTS Amount', '28d Resurrected Person NTS Amount',
                                '28d Early life Person moved to Retained', '28d Retained Person moved to Retained', '28d Resurrected Person moved to Retained',
                                '28d Early life Person moved to Churned', '28d Retained Person moved to Churned', '28d Resurrected Person moved to Churned',
                                '28d Active Customers', '28d Active Person NTS Amount', '28d Person moved Active to Inactive',
                                'Number of Customers', 'Net Sales Amount', 'Total number of Orders')
            AND week_commencing_date IN
                                (
                                    SELECT DISTINCT week_commencing_date FROM calendar_data
                                )
    ),
    ret_fytd as 
    (
        SELECT
            'FYtD' AS date_scope,
            retention.financial_year AS financial_year,
            retention.week_number AS week_number,
            retention.week_commencing_date AS year_month_day,
            CAST(current_time AS timestamp) AS last_modified,
            retention.week_commencing_date AS week_commencing_date,
            retention.product_pl AS product_pl,
            retention.region AS region,
            retention.category AS category,
            retention.sub_category AS sub_category,
            retention.metric_name AS metric_name,
            retention.metric_value AS metric_value
        FROM
        (
            SELECT
                financial_year,
                week_number,
                year_month_day,
                week_commencing_date,
                product_pl,
                region,
                category,
                sub_category,
                metric_name,
                metric_value
            FROM
                fytd_aggregation_others
            WHERE
                week_commencing_date = year_month_day

            UNION ALL

            -- Calculate Transctions per Customer
            SELECT
                    tr.financial_year,
                    tr.week_number,
                    tr.year_month_day,
                    tr.week_commencing_date,
                    tr.product_pl,
                    tr.region,
                    'Frequency' AS category,
                    tr.sub_category,
                    'Transactions per Customer' AS metric_name,
                    IF(cu.metric_value > 0, ((tr.metric_value*1.0000)/(cu.metric_value*1.0000)), 0) AS metric_value
                FROM
                    (select * from fytd_aggregation_others where week_commencing_date = year_month_day) tr
                INNER JOIN
                    (select * from fytd_aggregation_others where week_commencing_date = year_month_day) cu
                ON
                    date(tr.week_commencing_date) = date(cu.week_commencing_date)
                    AND tr.product_pl = cu.product_pl
                    AND tr.region = cu.region
                    AND tr.sub_category = cu.sub_category
                    AND tr.metric_name = 'Total number of Orders'
                    AND cu.metric_name = 'Number of Customers'
        ) retention
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    ret_fytd 
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
/* -- Script Name = retention_fytd.sql :: END -- */
{%- endmacro -%}
