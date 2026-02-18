-- UPDATED ON 18-Sep-2024 || DQ VERIFIED || CODE REVIEWED

-- DELETE FROM "my_company_data"."stg_wbr_mart"."retention_mart" WHERE date_scope = 'DAY';

{%- macro retention_day() -%}
/* -- Script Name = retention_day.sql :: BEGIN -- */
WITH 
    retention_metrics AS 
    (
     {{ growth_accounting_metrics() }}
    )
    , user_journey_metrics AS
    (
    {{ user_journey_metrics() }}
    )
    , day_metrics AS
    (
        SELECT 'DAY' AS date_scope,
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
        ON (date(retention.year_month_day) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
    )
    , day_final AS
    (
        select *
        from   day_metrics day
        where day.year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
    ),
    ret_day as 
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
        from  day_final
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
        from   day_final ret
        join   day_final vol
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
        from   day_final ret
        join   day_final vol
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
        from   day_final el_vol
        join   day_final ret_vol
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
        from   day_final ret_vol
        join   day_final res_vol
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
        from   day_final churn_active
        join   day_final el_active
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

        SELECT 'DAY' AS date_scope,
            calendar.financial_year AS financial_year,
            calendar.week_number AS week_number,
            user_journey.year_month_day AS year_month_day,
            CAST(current_time AS timestamp) AS last_modified,
            calendar.week_commencing_date AS week_commencing_date,
            user_journey.product_pl,
            user_journey.region,
            user_journey.category,
            user_journey.sub_category,
            user_journey.metric_name,
            user_journey.metric_value
        from user_journey_metrics user_journey
        INNER JOIN
            {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
            ON (date(user_journey.year_month_day) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
        WHERE 1=1
        AND user_journey.year_month_day IS NOT NULL
        AND user_journey.category IS NOT NULL
        AND user_journey.sub_category IS NOT NULL
        AND user_journey.metric_name IS NOT NULL
        AND user_journey.metric_value IS NOT NULL

    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    ret_day 
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
/* -- Script Name = retention_day.sql :: END -- */
{%- endmacro -%}

