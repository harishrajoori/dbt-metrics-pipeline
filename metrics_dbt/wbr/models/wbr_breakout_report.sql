-- UPDATED ON 18-Sep-2024 || DQ VERIFIED || CODE REVIEWED

-- DELETE FROM "my_company_data"."stg_wbr_mart"."wbr_overview_status";

{% set exe_type = env_var("exe_type") %}

{% do exceptions.warn("exe_type Got: " ~ exe_type) %}
{% do exceptions.warn("date scope Got: " ~ env_var("exe_start_date")) %}
WITH
    /* ---
    below CTE collates the data from all the individual LTV Segment base tables,
    while filtering out the aggregated records at "region" and "platform" levels
    --- */
    base_metrics_collated AS
    (
        SELECT
            'acquisition_mart' as metric_mart_name,
             date_scope,
             financial_year,
             week_number,
             year_month_day,
             week_commencing_date,product_pl,
             region,
             category,
             sub_category,
             metric_name,
             COALESCE(metric_value,0) AS metric_value
        FROM
            {{ ref("acquisition_mart") }}
        UNION ALL
        SELECT
            'monetisation_mart' as metric_mart_name,date_scope,financial_year,week_number,year_month_day,week_commencing_date,product_pl,region,category,sub_category,metric_name,COALESCE(metric_value,0) AS metric_value
        FROM
            {{ ref("monetisation_mart") }}
        UNION ALL
        SELECT
            'conversion_mart' as metric_mart_name,date_scope,financial_year,week_number,year_month_day,week_commencing_date,product_pl,region,category,sub_category,metric_name,COALESCE(metric_value,0) AS metric_value
        FROM
             {{ ref("conversion_mart") }}
        UNION ALL
        SELECT
             'retention_mart' as metric_mart_name,date_scope,financial_year,week_number,year_month_day,week_commencing_date,product_pl,region,category,sub_category,metric_name,COALESCE(metric_value,0) AS metric_value
         FROM
             {{ ref("retention_mart") }}
         WHERE
             metric_name IN
             (
              '28d Active Person NTS Amount',
              'EL moved to Retained over Previous New',
              '28d Active Customers',
              'Retained moved to Retained over Previous Retained',
              'Resurrected moved to Churn over Previous Resurrected',
              'EL moved to Churn over Previous New',
              'Current Resurrected over current Retained + current Resurrected',
              '28d Active to Inactive over Previous active',
              '28d Early life Person moved to Churned',
              '28d Retained Person NTS Amount',
              '28d Early life Person NTS Amount',
              '28d Early life Person Count',
              'Resurrected moved to Retained over Previous Resurrected',
              '28d Retained Person Count',
              '28d Resurrected Person moved to Retained',
              '28d Retained Person moved to Retained',
              'Retained moved to Churn over Previous Retained',
              '28d Resurrected Person moved to Churned',
              'Current EL over Current EL + Current Retained',
              '28d Resurrected Person NTS Amount',
              '28d Resurrected Person Count',
              '28d Early life Person moved to Retained',
              '28d Person moved Active to Inactive',
              '28d Retained Person moved to Churned',
              'Number of Customers',
              'Net Sales Amount',
              'Transactions per Customer'
             )
         UNION ALL
         SELECT
             'supply_mart' as metric_mart_name,date_scope,financial_year,week_number,year_month_day,week_commencing_date,product_pl,region,category,sub_category,metric_name,COALESCE(metric_value,0) AS metric_value
         FROM
             {{ ref("supply_mart") }}
         WHERE metric_name IN
             (
                 'WBR Gross Sales',
                 'Gross Sales Budget',
                 'WBR Net Sales',
                 'Net Sales Budget',
                 'Total Refunds',
                 'Refunds Ratio',
                 'Total Journeys',
                 'Unsellable Journeys',
                 'Unsellable Journey Ratio',
                 'New Customers Budget',
                 'Marketing Spend Budget',
                 'Total Revenue Budget',
                 'Total Costs Budget',
                 'Gross Margin Budget',
                 'GM - PMS Budget'
             )
    ),
    /* ---
    below CTE collated all the reporting weeks in the entire dataset and numbers them sequentially,
    which will be used while comparing this week's metric values with those of last week / last year
    --- */
    week_sequence AS
    (
        select distinct
            row_number() over(order by week_commencing_date) as week_seq,
            week_commencing_date
        from
            (select distinct week_commencing_date from base_metrics_collated)
    ),
    /* ---
    below CTE generates a collated dataset from the individual LTV Segment base tables,
    and the sequential reporting week dataset, to achieve the final dataset with all required attributes
    --- */
    base_metrics_sequenced AS
    (
        SELECT DISTINCT
            b.metric_mart_name,
            b.date_scope,
            b.financial_year,
            b.week_number,
            b.year_month_day,
            s.week_seq,
            b.week_commencing_date,
            b.product_pl,
            b.region,
            b.category,
            b.sub_category,
            b.metric_name,
            b.metric_value
        FROM
            (
                SELECT DISTINCT
                    metric_mart_name,
                    date_scope,
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
                    base_metrics_collated
                WHERE 1=1 -- same filters used in the base tables so commenting out here
{#                    (#}
{#                        (#}
{#                            product_pl = 'EU'#}
{#                            AND#}
{#                            region not in ('Total', 'United Kingdom')#}
{#                        )#}
{#                        OR#}
{#                        (#}
{#                            product_pl = 'UK'#}
{#                            AND#}
{#                            region = 'United Kingdom'#}
{#                        )#}
{#                        OR#}
{#                        (#}
{#                            product_pl = 'UK & EU'#}
{#                            AND#}
{#                            region = 'Total'#}
{#                        )#}
{#                    )#}
            ) b
        INNER JOIN
            week_sequence s
            ON (date(b.week_commencing_date) = date(s.week_commencing_date))
    ),
    /* ---
    below CTE uses 3 copies of the collated dataset created above, one for this scope,
    one for 1 week old (wow) and one for 52 weeks old (yoy) to generate a 3-way comparison
    for DAY and WEEK scope data
    --- */
    past_present_day_week_comparison AS
    (
        SELECT DISTINCT
            thisscope.metric_mart_name AS metric_mart_name,
            thisscope.date_scope AS date_scope,
            thisscope.financial_year AS financial_year,
            thisscope.week_number AS week_number,
            thisscope.year_month_day AS year_month_day,
            thisscope.week_commencing_date AS week_commencing_date,
            thisscope.product_pl AS product_pl,
            thisscope.region AS region,
            thisscope.category AS category,
            thisscope.sub_category AS sub_category,
            thisscope.metric_name AS metric_name,
            thisscope.week_seq AS this_scope_week_seq,
            thisscope.metric_value AS this_scope_metric_value,
            weekold.week_seq AS week_old_week_seq,
            weekold.metric_value AS week_old_metric_value,
            yearold.week_seq AS year_old_week_seq,
            yearold.metric_value AS year_old_metric_value,
            COALESCE(thisscope.metric_value-weekold.metric_value, 0) AS wow,
            IF(COALESCE(weekold.metric_value,0) > 0, (((thisscope.metric_value-weekold.metric_value)*1.0000000)/(weekold.metric_value*1.0000000)), 0) AS wow_ratio,
            COALESCE(thisscope.metric_value-yearold.metric_value, 0) AS yoy,
            IF(COALESCE(yearold.metric_value,0) > 0, (((thisscope.metric_value-yearold.metric_value)*1.0000000)/(yearold.metric_value*1.0000000)), 0) AS yoy_ratio
        FROM
            (select * from base_metrics_sequenced where date_scope IN ('DAY', 'WEEK')) thisscope
        LEFT JOIN
            (select * from base_metrics_sequenced where date_scope IN ('DAY', 'WEEK')) weekold
            ON
            (
                (thisscope.date_scope = weekold.date_scope)
                AND 
                (thisscope.week_seq = weekold.week_seq+1)
                AND
                (thisscope.year_month_day = date_add('week', 1, weekold.year_month_day))
                AND 
                (thisscope.week_commencing_date = date_add('week', 1, weekold.week_commencing_date))
                AND
                (thisscope.product_pl = weekold.product_pl)
                AND
                (thisscope.region = weekold.region)
                AND
                (thisscope.metric_name = weekold.metric_name)
                AND
                (thisscope.category = weekold.category)
                AND
                (thisscope.sub_category = weekold.sub_category)
                AND
                (thisscope.metric_mart_name = weekold.metric_mart_name)
            )
        LEFT JOIN
            (select * from base_metrics_sequenced where date_scope IN ('DAY', 'WEEK')) yearold
            ON
            (
                (thisscope.date_scope = yearold.date_scope)
                AND 
                (thisscope.week_seq = yearold.week_seq+52)
                AND
                (thisscope.year_month_day = date_add('week', 52, yearold.year_month_day))
                AND 
                (thisscope.week_commencing_date = date_add('week', 52, yearold.week_commencing_date))
                AND
                (thisscope.product_pl = yearold.product_pl)
                AND
                (thisscope.region = yearold.region)
                AND
                (thisscope.metric_name = yearold.metric_name)
                AND
                (thisscope.category = yearold.category)
                AND
                (thisscope.sub_category = yearold.sub_category)
                AND
                (thisscope.metric_mart_name = yearold.metric_mart_name)
            )
    ),
    /* ---
    below CTE uses 2 copies of the collated dataset created above, one for this scope,
    and another one for 52 weeks old (yoy) to generate a 2-way comparison
    for FYtD scope data
    --- */
    past_present_fytd_comparison AS
    (
        SELECT DISTINCT
            thisscope.metric_mart_name AS metric_mart_name,
            thisscope.date_scope AS date_scope,
            thisscope.financial_year AS financial_year,
            thisscope.week_number AS week_number,
            thisscope.year_month_day AS year_month_day,
            thisscope.week_commencing_date AS week_commencing_date,
            thisscope.product_pl AS product_pl,
            thisscope.region AS region,
            thisscope.category AS category,
            thisscope.sub_category AS sub_category,
            thisscope.metric_name AS metric_name,
            thisscope.week_seq AS this_scope_week_seq,
            thisscope.metric_value AS this_scope_metric_value,
            NULL AS week_old_week_seq,
            NULL AS week_old_metric_value,
            yearold.week_seq AS year_old_week_seq,
            yearold.metric_value AS year_old_metric_value,
            NULL AS wow,
            NULL AS wow_ratio,
            COALESCE(thisscope.metric_value-yearold.metric_value, 0) AS yoy,
            IF(COALESCE(yearold.metric_value,0) > 0, (((thisscope.metric_value-yearold.metric_value)*1.0000000)/(yearold.metric_value*1.0000000)), 0) AS yoy_ratio
        FROM
            (select * from base_metrics_sequenced where date_scope = 'FYtD') thisscope
        LEFT JOIN
            (select * from base_metrics_sequenced where date_scope = 'FYtD') yearold
            ON
            (
                (thisscope.date_scope = yearold.date_scope)
                AND 
                (thisscope.week_seq = yearold.week_seq+52)
                AND
                (thisscope.year_month_day = date_add('week', 52, yearold.year_month_day))
                AND 
                (thisscope.week_commencing_date = date_add('week', 52, yearold.week_commencing_date))
                AND
                (thisscope.product_pl = yearold.product_pl)
                AND
                (thisscope.region = yearold.region)
                AND
                (thisscope.category = yearold.category)
                AND
                (thisscope.sub_category = yearold.sub_category)
                AND
                (thisscope.metric_name = yearold.metric_name)
                AND
                (thisscope.metric_mart_name = yearold.metric_mart_name)
            )
    ),
    /* ---
    below CTE generates placeholder values for this scope, week-on-week (wow)
    growth / depreciation and year-on-year (yoy) growth / depreciation for each metric,
    corresponding to all future weeks in the current financial year, for all 3 date scopes
    --- */
    future_day_week_fytd_comparison AS
    (
        SELECT DISTINCT
            base.metric_mart_name AS metric_mart_name,
            base.date_scope AS date_scope,
            cal.financial_year AS financial_year,
            cal.week_number AS week_number,
            cal.year_month_day AS year_month_day,
            cal.week_commencing_date AS week_commencing_date,
            base.product_pl AS product_pl,
            base.region AS region,
            base.category AS category,
            base.sub_category AS sub_category,
            base.metric_name AS metric_name,
            NULL AS this_scope_week_seq,
            NULL AS this_scope_metric_value,
            NULL AS week_old_week_seq,
            NULL AS week_old_metric_value,
            NULL AS year_old_week_seq,
            NULL AS year_old_metric_value,
            NULL AS wow,
            NULL AS wow_ratio,
            NULL AS yoy,
            NULL AS yoy_ratio
        FROM
        (
            SELECT DISTINCT
                metric_mart_name,
                date_scope,
                product_pl,
                region,
                category,
                sub_category,
                metric_name
            FROM
                base_metrics_sequenced
            WHERE
                metric_name NOT LIKE '%Budget%'
        ) base
        CROSS JOIN
        (
            SELECT
                year_month_day,
                financial_year,
                week_number,
                week_commencing_date
            FROM
                {{ source("data_metrics_layer", "calendar_dates_lookup") }}
            WHERE
                year_month_day > current_date
                AND 
                week_commencing_date > current_date
        ) cal
    )
SELECT
    metric_mart_name AS metric_mart_name,
    date_scope AS date_scope,
    financial_year AS financial_year,
    week_number AS week_number,
    year_month_day AS year_month_day,
    CAST(current_timestamp AS timestamp) AS last_modified,
    week_commencing_date AS week_commencing_date,
    product_pl AS product_pl,
    region AS region,
    category AS category,
    sub_category AS sub_category,
    UPPER(REPLACE(metric_name, '_', ' ')) AS metric_name,
    this_scope_metric_value AS metric_value,
    wow AS wow,
    wow_ratio AS wow_ratio,
    yoy AS yoy,
    yoy_ratio AS yoy_ratio
FROM
    (
        SELECT * FROM past_present_day_week_comparison
        UNION ALL
        SELECT * FROM past_present_fytd_comparison
        UNION ALL 
        SELECT * FROM future_day_week_fytd_comparison
    )
WHERE this_scope_metric_value is not null

