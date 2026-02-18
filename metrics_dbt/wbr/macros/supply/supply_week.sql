-- UPDATED ON 24-Oct-2024

-- DELETE FROM "my_company_data"."dev_data_metrics_layer"."supply_mart" WHERE date_scope = 'WEEK';

{%- macro supply_week() -%}
/* -- Script Name = supply_week.sql :: BEGIN -- */
WITH
    /* ---
    below CTE extracts all the year_month_day dates which correspond
    to the week_commencing_dates that fall between the start and end dates
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
    below CTE generates WEEK level aggregations for budget metrics
    --- */
    week_aggregation_budget AS
    (
        /* -- for solo EU and UK regions -- */
        SELECT
            to_date(report_week_commencing, 'dd/mm/yy') AS week_commencing_date,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            Case when region ='United Kingdom' then 'UK' else 'EU' end as product_pl,
            region,
            /* ------------------------------------------------------------------------------------------------------- -- */
            /* -- no segregation of budget allocation at category and sub_category level at the moment -- */
            'All' AS category,
            'All' AS sub_category,
            gross_sales_budget,
            net_sales_budget,
            total_revenue_budget,
            total_costs_budget,
            gross_margin_budget,
            marketing_spend_budget,
            gm_minus_pms_budget,
            new_customers_budget
        FROM
            {{ source("tmp_bi_dwh", "budget_allocation") }} -- changes as per dat-1641 (create 2 different copies of budget allocation table)
        -- Commenting out the table join as this was becoming a cross join because product pl and dashboard just presents
        -- data at region level only
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
--        inner join
--            {{ source("data_metrics_layer", "product_pl_region_map") }} rm
--            on (rm.input_product_pl in ('EU', 'UK') and coalesce(region, '(null)') = rm.input_region)
        /* ------------------------------------------------------------------------------------------------------- -- */
        WHERE
            to_date(report_week_commencing, 'dd/mm/yy') BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
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
        WHERE metric_name IN ('WBR Gross Sales', 'WBR Net Sales', 'Total Refunds', 'Total Journeys', 'Unsellable Journeys')
        AND date_scope = 'DAY'
        AND week_commencing_date IN
        (
            SELECT DISTINCT week_commencing_date
            FROM calendar_data
        )
        GROUP BY 1,2,3,4,5,6
    ),
    sup_week as 
    (
        SELECT
            'WEEK' AS date_scope,
            calendar.financial_year AS financial_year,
            calendar.week_number AS week_number,
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
                week_commencing_date,
                product_pl,
                region,
                metric_name,
                metric_value
            FROM
                week_aggregation_others
            UNION ALL
            SELECT
                tr.week_commencing_date,
                tr.product_pl,
                tr.region,
                'Refunds Ratio' AS metric_name,
                IF(gs.metric_value > 0, ((tr.metric_value*1.0000000)/(gs.metric_value*1.0000000)), 0) AS metric_value
            FROM
                week_aggregation_others tr
            INNER JOIN
                week_aggregation_others gs
                ON
                (
                    date(tr.week_commencing_date) = date(gs.week_commencing_date)
                    AND
                    tr.product_pl = gs.product_pl
                    AND
                    tr.region = gs.region
                    AND
                    tr.metric_name = 'Total Refunds'
                    AND
                    gs.metric_name = 'WBR Gross Sales'
                )
            UNION ALL
            SELECT
                uj.week_commencing_date,
                uj.product_pl,
                uj.region,
                'Unsellable Journey Ratio' AS metric_name,
                IF(tj.metric_value > 0, ((uj.metric_value*1.0000000)/(tj.metric_value*1.0000000)), 0) AS metric_value
            FROM
                week_aggregation_others uj
            INNER JOIN
                week_aggregation_others tj
                ON
                (
                    date(uj.week_commencing_date) = date(tj.week_commencing_date)
                    AND
                    uj.product_pl = tj.product_pl
                    AND
                    uj.region = tj.region
                    AND
                    uj.metric_name = 'Unsellable Journeys'
                    AND
                    tj.metric_name = 'Total Journeys'
                )

            -- Budget Data --
            UNION ALL

            SELECT t1.week_commencing_date, t1.product_pl, t1.region,
                t2.metric_name, t2.metric_value
            FROM week_aggregation_budget t1
            CROSS JOIN unnest (
            array['Gross Sales Budget', 'Net Sales Budget','Total Revenue Budget', 'Total Costs Budget', 'Gross Margin Budget',
                  'Marketing Spend Budget','GM - PMS Budget', 'New Customers Budget'],
            array[ gross_sales_budget, net_sales_budget, total_revenue_budget, total_costs_budget, gross_margin_budget,
                   marketing_spend_budget, gm_minus_pms_budget, new_customers_budget ]
            ) t2 (metric_name, metric_value)
        ) supply
        INNER JOIN
            {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
            ON (date(supply.week_commencing_date) = date(calendar.week_commencing_date) AND calendar.date_scope = 'WEEK')
        WHERE
        (
            supply.week_commencing_date IS NOT NULL
        )
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    sup_week 
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
/* -- Script Name = supply_week.sql :: END -- */
{%- endmacro -%}
