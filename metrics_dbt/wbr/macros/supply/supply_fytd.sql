-- UPDATED ON 24-Oct-2024

-- DELETE FROM "my_company_data"."dev_data_metrics_layer"."supply_datamart" WHERE date_scope = 'FYtD';

{%- macro supply_fytd() -%}
/* -- Script Name = supply_fytd.sql :: BEGIN -- */
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
            {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
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
    at DAY level from supply_mart
    --- */
    fytd_aggregation_others AS
    (
        SELECT distinct
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
            AND metric_name IN ('WBR Gross Sales', 'WBR Net Sales', 'Total Refunds', 'Total Journeys', 'Unsellable Journeys')
            AND week_commencing_date IN
                                (
                                    SELECT DISTINCT week_commencing_date FROM calendar_data
                                )
    ),
    /* ---
    below CTE is to extract budget metric values from supply_mart
    --- */
    fytd_aggregation_budget AS
    (
        SELECT distinct
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
            AND metric_name IN ('Gross Sales Budget', 'Net Sales Budget','Total Revenue Budget', 'Total Costs Budget',
                                'Gross Margin Budget', 'Marketing Spend Budget','GM - PMS Budget', 'New Customers Budget')
            AND week_commencing_date IN
                (
                    SELECT DISTINCT week_commencing_date FROM calendar_data
                )
    ),
    sup_fytd as 
    (
        SELECT
            'FYtD' AS date_scope,
            supply.financial_year AS financial_year,
            supply.week_number AS week_number,
            supply.week_commencing_date AS year_month_day,
            CAST(current_time AS timestamp) AS last_modified,
            supply.week_commencing_date AS week_commencing_date,
            supply.product_pl AS product_pl,
            supply.region AS region,
            'All' AS category,
            'All' AS sub_category,
            supply.metric_name AS metric_name,
            supply.metric_value AS metric_value
        FROM
        (
            SELECT
                financial_year,
                week_number,
                year_month_day,
                week_commencing_date,
                product_pl,
                region,
                metric_name,
                metric_value
            FROM
                fytd_aggregation_others
            WHERE
                week_commencing_date = year_month_day
            UNION ALL
            SELECT
                tr.financial_year,
                tr.week_number,
                tr.year_month_day,
                tr.week_commencing_date,
                tr.product_pl,
                tr.region,
                'Refunds Ratio' AS metric_name,
                IF(gs.metric_value > 0, ((tr.metric_value*1.0000000)/(gs.metric_value*1.0000000)), 0) AS metric_value
            FROM
                (SELECT * FROM fytd_aggregation_others WHERE week_commencing_date = year_month_day AND metric_name = 'Total Refunds') tr
            INNER JOIN
                (SELECT * FROM fytd_aggregation_others WHERE week_commencing_date = year_month_day AND metric_name = 'WBR Gross Sales') gs
                ON
                (
                    date(tr.week_commencing_date) = date(gs.week_commencing_date)
                    AND
                    tr.product_pl = gs.product_pl
                    AND
                    tr.region = gs.region
                )
            UNION ALL
            SELECT
                tj.financial_year,
                tj.week_number,
                tj.year_month_day,
                tj.week_commencing_date,
                tj.product_pl,
                tj.region,
                'Unsellable Journey Ratio' AS metric_name,
                IF(tj.metric_value > 0, ((uj.metric_value*1.0000000)/(tj.metric_value*1.0000000)), 0) AS metric_value
            FROM
                (SELECT * FROM fytd_aggregation_others WHERE week_commencing_date = year_month_day AND metric_name = 'Unsellable Journeys') uj
            INNER JOIN
                (SELECT * FROM fytd_aggregation_others WHERE week_commencing_date = year_month_day AND metric_name = 'Total Journeys') tj
                ON
                (
                    date(uj.week_commencing_date) = date(tj.week_commencing_date)
                    AND
                    uj.product_pl = tj.product_pl
                    AND
                    uj.region = tj.region
                )

            -- Budget Data --
            UNION ALL
            SELECT
                financial_year,
                week_number,
                year_month_day,
                week_commencing_date,
                product_pl,
                region,
                metric_name,
                metric_value
            FROM
                fytd_aggregation_budget
        ) supply
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    sup_fytd 
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
/* -- Script Name = supply_fytd.sql :: END -- */
{%- endmacro -%}
