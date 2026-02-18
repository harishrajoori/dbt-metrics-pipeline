-- UPDATED ON 18-Sep-2024 || DQ VERIFIED || CODE REVIEWED

-- DELETE FROM "my_company_data"."stg_wbr_mart"."conversion_datamart" WHERE date_scope = 'FYtD';

{%- macro conversion_fytd() -%}
/* -- Script Name = conversion_fytd.sql :: BEGIN -- */
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
    at DAY level from conversion_mart
    --- */
    fytd_aggregation_others AS
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
            SUM(metric_value) OVER (PARTITION BY financial_year,product_pl,region,category,sub_category,metric_name ORDER BY week_commencing_date) AS metric_value
        FROM
            {{ this }}
        WHERE
            date_scope = 'WEEK'
            AND metric_name IN ('Gross Sales', 'WBR Gross Transactions', 'Total Visits', 'Transactions Tracked')
            AND week_commencing_date IN
                                (
                                    SELECT DISTINCT week_commencing_date FROM calendar_data
                                )
    ),
    /* ---
    below CTE is to extract budget metric values
    at WEEK level from conversion_mart
    --- */
    fytd_aggregation_budget AS
    (
        SELECT DISTINCT
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
            AND metric_name IN ('Gross Transactions Budget', 'Gross Sales Budget')
            AND week_commencing_date IN
                                (
                                    SELECT DISTINCT week_commencing_date FROM calendar_data
                                )
    )
    ,
    fytd_aggregation_avg_trans_budget AS
    (
        SELECT DISTINCT
            gs.financial_year,
            gs.week_number,
            gs.year_month_day,
            gs.week_commencing_date,
            gs.product_pl,
            gs.region,
            gs.category,
            gs.sub_category,
            'Avg Trans Value Budget' AS metric_name,
            IF(gt.metric_value > 0, ((gs.metric_value*1.0000)/(gt.metric_value*1.0000)), 0) AS metric_value
        FROM
            fytd_aggregation_budget gs
        INNER JOIN
            fytd_aggregation_budget gt
        ON
        (
            date(gs.week_commencing_date) = date(gt.week_commencing_date)
            AND gs.product_pl = gt.product_pl
            AND gs.region = gt.region
            AND gs.category = gt.category
            AND gs.sub_category = gt.sub_category
            AND gs.metric_name = 'Gross Sales Budget'
            AND gt.metric_name = 'Gross Transactions Budget'
        )
    ),
    cnv_fytd as 
    (
        SELECT
            'FYtD' AS date_scope,
            conversion.financial_year AS financial_year,
            conversion.week_number AS week_number,
            conversion.week_commencing_date AS year_month_day,
            CAST(current_time AS timestamp) AS last_modified,
            conversion.week_commencing_date AS week_commencing_date,
            conversion.product_pl AS product_pl,
            conversion.region AS region,
            conversion.category AS category,
            conversion.sub_category AS sub_category,
            conversion.metric_name AS metric_name,
            conversion.metric_value AS metric_value
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
            select * from (
            select 	t1.financial_year,
                    t1.week_number,
                    t1.year_month_day,
                    t1.week_commencing_date,
                    t1.product_pl,
                    t1.region,
                    t1.category,
                    t1.sub_category,
                    t2.metric_name,
                    t2.metric_value
                    from (

                        select financial_year,
                                week_number,
                                year_month_day,
                                week_commencing_date,
                                product_pl,
                                region,
                                category,
                                sub_category,
                                IF(gross_transactions > 0, ((gross_sales*1.0000000)/(gross_transactions*1.0000000)), 0) AS avg_trans_value,
                                IF(total_visits > 0, ((transaction_tracked*1.0000000)/(total_visits*1.0000000)), 0) AS conversion_ratio
                        from
                        (

                            select financial_year,
                                    week_number,
                                    year_month_day,
                                    week_commencing_date,
                                    product_pl,
                                    region,
                                    category,
                                    sub_category,
                                    coalesce(element_at(key,'Gross Sales'),0) AS gross_sales,
                                    coalesce(element_at(key,'WBR Gross Transactions'),0) AS gross_transactions,
                                    coalesce(element_at(key,'Transactions Tracked'),0) AS transaction_tracked,
                                    coalesce(element_at(key,'Total Visits'),0) AS total_visits
                            FROM (
                                    SELECT financial_year,
                                            week_number,
                                            year_month_day,
                                            week_commencing_date,
                                            product_pl,
                                            region,
                                            category,
                                            sub_category,
                                            map_agg(metric_name, metric_value) key
                                    FROM  fytd_aggregation_others
                                    where week_commencing_date = year_month_day
                                    AND  metric_name in ('Gross Sales','WBR Gross Transactions','Transactions Tracked','Total Visits')
                                    GROUP BY financial_year,
                                            week_number,
                                            year_month_day,
                                            week_commencing_date,
                                            product_pl,
                                            region,
                                            category,
                                            sub_category
                                ) )

                        ) t1
                    CROSS JOIN unnest (
                    array['Avg Trans Value', 'Conversion Ratio'],
                    array[avg_trans_value, conversion_ratio]
                    ) t2 (metric_name, metric_value)
                )
            where coalesce(metric_value,0) <> 0

            UNION ALL

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
                fytd_aggregation_budget
            WHERE
                metric_name IN ('Gross Transactions Budget')
            UNION ALL
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
                fytd_aggregation_avg_trans_budget
        ) conversion
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    cnv_fytd
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
/* -- Script Name = conversion_fytd.sql :: END -- */
{%- endmacro -%}