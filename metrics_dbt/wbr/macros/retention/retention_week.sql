-- UPDATED ON 18-Sep-2024 || DQ VERIFIED || CODE REVIEWED

-- DELETE FROM "my_company_data"."stg_wbr_mart"."retention_mart" WHERE date_scope = 'WEEK';

{%- macro retention_week() -%}
/* -- Script Name = retention_week.sql :: BEGIN -- */
WITH 
    retention_metrics AS 
    (
     {{ growth_accounting_metrics() }}
    )
    , week_metrics AS
    (
        SELECT 'WEEK' AS date_scope,
            calendar.financial_year AS financial_year,
            calendar.week_number AS week_number,
            retention.year_month_day AS year_month_day,
            CAST(current_time AS timestamp) AS last_modified,
            calendar.week_commencing_date AS week_commencing_date,
            retention.product_pl,
            retention.region,
            retention.category,
            retention.sub_category,
            CASE category
            WHEN 'Volume'
                THEN CASE sub_category
                        WHEN 'Early Life' THEN '28d Early life Person Count'
                        WHEN 'Retained' THEN '28d Retained Person Count'
                        WHEN 'Resurrected' THEN '28d Resurrected Person Count'
                        WHEN 'Active' THEN '28d Active Customers'
                    END
            WHEN 'Net Sales Amount'
                THEN CASE sub_category
                        WHEN 'Early Life' THEN '28d Early life Person NTS Amount'
                        WHEN 'Retained' THEN '28d Retained Person NTS Amount'
                        WHEN 'Resurrected' THEN '28d Resurrected Person NTS Amount'
                        WHEN 'Active' THEN '28d Active Person NTS Amount'
                    END
            WHEN 'Retention'
                THEN CASE sub_category
                        WHEN 'Early Life' THEN '28d Early life Person moved to Retained'
                        WHEN 'Retained' THEN '28d Retained Person moved to Retained'
                        WHEN 'Resurrected' THEN '28d Resurrected Person moved to Retained'
                    END
            WHEN 'Churn'
                THEN CASE sub_category
                        WHEN 'Early Life' THEN '28d Early life Person moved to Churned'
                        WHEN 'Retained' THEN '28d Retained Person moved to Churned'
                        WHEN 'Resurrected' THEN '28d Resurrected Person moved to Churned'
                        WHEN 'Active' THEN '28d Person moved Active to Inactive'
                    END
            END metric_name,
            metric_value,
            lag(metric_value) over(partition by product_pl,region,category,sub_category order by retention.year_month_day) prev_metric_value
        from retention_metrics retention
        INNER JOIN
            {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
            ON (date(retention.year_month_day) = date(calendar.year_month_day) AND calendar.date_scope = 'WEEK')
            WHERE 1=1
            AND retention.year_month_day IS NOT NULL
            AND retention.date_scope IS NOT NULL
            AND retention.category IS NOT NULL
            AND retention.sub_category IS NOT NULL
    )
    , week_final AS
    (
        select *
        from   week_metrics week
        where week.year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
    )
    , calendar_data AS
    (
        /* ---
        below CTE extracts all the year_month_day dates which correspond
        to the week_commencing_dates that fall between the start and end dates
        --- */
        SELECT
            financial_year,
            week_number,
            week_commencing_date,
            year_month_day
        FROM
            {{ source("data_metrics_layer", "calendar_dates_lookup") }}
        WHERE
            date_scope = 'DAY'
            AND week_commencing_date IN
            (
                SELECT DISTINCT week_commencing_date
                FROM {{ source("data_metrics_layer", "calendar_dates_lookup") }}
                WHERE date_scope = 'DAY'
                AND date(year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            )
    )
    , user_journey_week_aggregations AS
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
        WHERE metric_name IN ('Number of Customers', 'Net Sales Amount', 'Total number of Orders')
        AND date_scope = 'DAY'
        AND week_commencing_date IN
        (
            SELECT DISTINCT week_commencing_date
            FROM calendar_data
        )
        GROUP BY 1,2,3,4,5,6
    ),
    ret_week as 
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
            metric_name,
            metric_value
        from  week_final
        UNION ALL
        select ret.date_scope,
            ret.financial_year,
            ret.week_number,
            ret.year_month_day,
            ret.last_modified,
            ret.week_commencing_date,
            ret.product_pl,
            ret.region,
            'Retention %' AS category,
            ret.sub_category,
            CASE ret.sub_category
                WHEN 'Early Life' THEN 'EL moved to Retained over Previous New'
                WHEN 'Retained' THEN 'Retained moved to Retained over Previous Retained'
                WHEN 'Resurrected' THEN 'Resurrected moved to Retained over Previous Resurrected'
            END metric_name,
            ret.metric_value/vol.prev_metric_value
        from   week_final ret
        join   week_final vol
        on ret.date_scope=vol.date_scope
        and ret.financial_year=vol.financial_year
        and ret.week_number=vol.week_number
        and ret.year_month_day=vol.year_month_day
        and ret.last_modified=vol.last_modified
        and ret.week_commencing_date=vol.week_commencing_date
        and ret.product_pl=vol.product_pl
        and ret.region=vol.region
        and ret.sub_category =vol.sub_category
        where ret.category = 'Retention'
        and vol.category='Volume'
        UNION ALL
        select ret.date_scope,
            ret.financial_year,
            ret.week_number,
            ret.year_month_day,
            ret.last_modified,
            ret.week_commencing_date,
            ret.product_pl,
            ret.region,
            'Churn %' AS category,
            ret.sub_category,
            CASE ret.sub_category
                WHEN 'Early Life' THEN 'EL moved to Churn over Previous New'
                WHEN 'Retained' THEN 'Retained moved to Churn over Previous Retained'
                WHEN 'Resurrected' THEN 'Resurrected moved to Churn over Previous Resurrected'
            END metric_name,
            ret.metric_value/vol.prev_metric_value
        from   week_final ret
        join   week_final vol
        on ret.date_scope=vol.date_scope
        and ret.financial_year=vol.financial_year
        and ret.week_number=vol.week_number
        and ret.year_month_day=vol.year_month_day
        and ret.last_modified=vol.last_modified
        and ret.week_commencing_date=vol.week_commencing_date
        and ret.product_pl=vol.product_pl
        and ret.region=vol.region
        and ret.sub_category =vol.sub_category
        where ret.category = 'Churn' and ret.sub_category <> 'Active'
        and vol.category='Volume'
        UNION ALL
        select el_vol.date_scope,
            el_vol.financial_year,
            el_vol.week_number,
            el_vol.year_month_day,
            el_vol.last_modified,
            el_vol.week_commencing_date,
            el_vol.product_pl,
            el_vol.region,
            'Proportion %' AS category,
            el_vol.sub_category,
            'Current EL over Current EL + Current Retained' metric_name,
            el_vol.metric_value/(ret_vol.metric_value+el_vol.metric_value) AS metric_value
        from   week_final el_vol
        join   week_final ret_vol
        on el_vol.date_scope=ret_vol.date_scope
        and el_vol.financial_year=ret_vol.financial_year
        and el_vol.week_number=ret_vol.week_number
        and el_vol.year_month_day=ret_vol.year_month_day
        and el_vol.last_modified=ret_vol.last_modified
        and el_vol.week_commencing_date=ret_vol.week_commencing_date
        and el_vol.product_pl=ret_vol.product_pl
        and el_vol.region=ret_vol.region
        and el_vol.category =ret_vol.category
        where el_vol.category = 'Volume'
        and el_vol.sub_category IN ('Early Life')
        and ret_vol.sub_category IN ('Retained')
        UNION ALL
        select res_vol.date_scope,
            res_vol.financial_year,
            res_vol.week_number,
            res_vol.year_month_day,
            res_vol.last_modified,
            res_vol.week_commencing_date,
            res_vol.product_pl,
            res_vol.region,
            'Proportion %' AS category,
            res_vol.sub_category,
            'Current Resurrected over current Retained + current Resurrected' metric_name,
            res_vol.metric_value/(ret_vol.metric_value+res_vol.metric_value) AS metric_value
        from   week_final ret_vol
        join   week_final res_vol
        on ret_vol.date_scope=res_vol.date_scope
        and ret_vol.financial_year=res_vol.financial_year
        and ret_vol.week_number=res_vol.week_number
        and ret_vol.year_month_day=res_vol.year_month_day
        and ret_vol.last_modified=res_vol.last_modified
        and ret_vol.week_commencing_date=res_vol.week_commencing_date
        and ret_vol.product_pl=res_vol.product_pl
        and ret_vol.region=res_vol.region
        and ret_vol.category =res_vol.category
        where ret_vol.category = 'Volume'
        and ret_vol.sub_category IN ('Retained')
        and res_vol.sub_category IN ('Resurrected')
        UNION ALL
        select churn_active.date_scope,
            churn_active.financial_year,
            churn_active.week_number,
            churn_active.year_month_day,
            churn_active.last_modified,
            churn_active.week_commencing_date,
            churn_active.product_pl,
            churn_active.region,
            'Churn %' AS category,
            churn_active.sub_category,
            '28d Active to Inactive over Previous active' metric_name,
            churn_active.metric_value/el_active.prev_metric_value AS metric_value
        from   week_final churn_active
        join   week_final el_active
        on churn_active.date_scope=el_active.date_scope
        and churn_active.financial_year=el_active.financial_year
        and churn_active.week_number=el_active.week_number
        and churn_active.year_month_day=el_active.year_month_day
        and churn_active.last_modified=el_active.last_modified
        and churn_active.week_commencing_date=el_active.week_commencing_date
        and churn_active.product_pl=el_active.product_pl
        and churn_active.region=el_active.region
        and churn_active.sub_category =el_active.sub_category
        where churn_active.category = 'Churn'
        and   el_active.category='Volume'
        and   el_active.sub_category='Active'

        UNION ALL

        -- Add user journey type metrics
        SELECT 'WEEK' AS date_scope,
            calendar.financial_year AS financial_year,
            calendar.week_number AS week_number,
            user_journey.week_commencing_date AS year_month_day,
            CAST(current_time AS timestamp) AS last_modified,
            calendar.week_commencing_date AS week_commencing_date,
            user_journey.product_pl,
            user_journey.region,
            user_journey.category,
            user_journey.sub_category,
            user_journey.metric_name,
            user_journey.metric_value
        FROM
        (
            SELECT
                week_commencing_date,
                product_pl,
                region,
                category,
                sub_category,
                metric_name,
                metric_value
            FROM
                user_journey_week_aggregations

            UNION ALL
            -- Add Transactions per Customer
            SELECT
                tr.week_commencing_date,
                tr.product_pl,
                tr.region,
                'Frequency' AS category,
                tr.sub_category,
                'Transactions per Customer' AS metric_name,
                IF(cu.metric_value > 0, ((tr.metric_value*1.0000)/(cu.metric_value*1.0000)), 0) AS metric_value
            FROM
                user_journey_week_aggregations tr
            INNER JOIN
                user_journey_week_aggregations cu
            ON
            (
                date(tr.week_commencing_date) = date(cu.week_commencing_date)
                AND tr.product_pl = cu.product_pl
                AND tr.region = cu.region
                AND tr.sub_category = cu.sub_category
                AND tr.metric_name = 'Total number of Orders'
                AND cu.metric_name = 'Number of Customers'
            )
        ) user_journey
        INNER JOIN
            {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
            ON (date(user_journey.week_commencing_date) = date(calendar.week_commencing_date) AND calendar.date_scope = 'WEEK')
            WHERE 1=1
            AND user_journey.week_commencing_date IS NOT NULL
            AND user_journey.category IS NOT NULL
            AND user_journey.sub_category IS NOT NULL
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    ret_week 
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
/* -- Script Name = retention_week.sql :: END -- */
{%- endmacro -%}

