-- UPDATED ON 18-Sep-2024 || DQ VERIFIED || CODE REVIEWED

-- DELETE FROM "my_company_data"."stg_wbr_mart"."conversion_mart" WHERE date_scope = 'WEEK';

{%- macro conversion_week() -%}
/* -- Script Name = conversion_week.sql :: BEGIN -- */
WITH
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
        WHERE metric_name IN ('Gross Sales', 'WBR Gross Transactions', 'Total Visits', 'Transactions Tracked' )
        AND date_scope = 'DAY'
        AND week_commencing_date IN
        (
            SELECT DISTINCT week_commencing_date
            FROM {{ this }}
            WHERE date_scope = 'DAY'
            AND date(year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
        )
        GROUP BY 1,2,3,4,5,6
    ),
    /* ---
    below CTE generates WEEK level aggregations for budget metrics (customer and non-customer)
    --- */
    week_aggregation_budget AS
    (
        SELECT
            week_commencing_date,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            product_pl,
            region,
            /* ------------------------------------------------------------------------------------------------------- -- */
            /* -- no segregation of budget allocation at category and sub_category level at the moment -- */
            'All' AS category,
            'All' AS sub_category,
            sum(gross_transactions_budget) AS gross_transactions_budget,
            sum(gross_sales_budget) AS gross_sales_budget
        FROM
        (
            SELECT
                to_date(ba.report_week_commencing, 'dd/mm/yy') AS week_commencing_date,
                /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
                rm.output_product_pl as product_pl,
                rm.output_region as region,
                /* ------------------------------------------------------------------------------------------------------- -- */
                ba.gross_transactions_budget,
                ba.gross_sales_budget,
                ba.average_transaction_value_budget AS avg_trans_value_budget
            FROM
                {{ source("tmp_bi_dwh", "budget_allocation") }} ba -- changes as per dat-1641 (create 2 different copies of budget allocation table)
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            inner join 
                {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
                on 
                (
                    (
                        (rm.input_product_pl = 'EU' and ba.region != 'United Kingdom')
                        OR 
                        (rm.input_product_pl = 'UK' and ba.region = 'United Kingdom')
                    )
                    AND 
                    (
                        ba.region = rm.input_region
                    )
                )            
            /* ------------------------------------------------------------------------------------------------------- -- */
            WHERE
                to_date(report_week_commencing, 'dd/mm/yy') BETWEEN date('{{ env_var("exe_start_date") }}')
                AND (SELECT
                        max(to_date(report_week_commencing, 'dd/mm/yy')) as max_report_week_commencing
                     FROM
                       {{ source("tmp_bi_dwh", "budget_allocation") }}) -- changes as per dat-1641 (create 2 different copies of budget allocation table)
        )
        group by cube (week_commencing_date, product_pl, region)
    ),
    cnv_week as 
    (
        SELECT
            'WEEK' AS date_scope,
            calendar.financial_year AS financial_year,
            calendar.week_number AS week_number,
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
                week_commencing_date,
                product_pl,
                region,
                category,
                sub_category,
                metric_name,
                metric_value
            FROM
                week_aggregation_others

            UNION ALL

            select *
            from (
            select 	t1.week_commencing_date,
                    t1.product_pl,
                    t1.region,
                    t1.category,
                    t1.sub_category,
                    t2.metric_name,
                    t2.metric_value
                    from (
                        select week_commencing_date,
                                product_pl,
                                region,
                                category,
                                sub_category,
                                IF(gross_transactions > 0, ((gross_sales*1.0000000)/(gross_transactions*1.0000000)), 0) AS avg_trans_value

                        from
                            ( select week_commencing_date,
                            product_pl,
                            region,
                            category,
                            sub_category,
                            coalesce(element_at(key,'Gross Sales'),0) AS gross_sales,
                            coalesce(element_at(key,'WBR Gross Transactions'),0) AS gross_transactions
                            FROM (
                                    SELECT week_commencing_date,
                                        product_pl,
                                        region,
                                        category,
                                        sub_category,
                                        map_agg(metric_name, metric_value) key
                                    FROM   week_aggregation_others
                                    WHERE  metric_name in ('Gross Sales','WBR Gross Transactions')
                                    GROUP BY week_commencing_date,
                                            product_pl,
                                            region,
                                            category,
                                            sub_category
                                )
                            )

                            ) t1
                    CROSS JOIN unnest (
                    array['Avg Trans Value'],
                    array[avg_trans_value]
                    ) t2 (metric_name, metric_value)

        UNION ALL

            select 	t1.week_commencing_date,
                    t1.product_pl,
                    t1.region,
                    t1.category,
                    t1.sub_category,
                    t2.metric_name,
                    t2.metric_value
                    from (
                        select week_commencing_date,
                                product_pl,
                                region,
                                category,
                                sub_category,
                                IF(total_visits > 0, ((transaction_tracked*1.0000000)/(total_visits*1.0000000)), 0) AS conversion_ratio

                        from
                            ( select week_commencing_date,
                            product_pl,
                            region,
                            category,
                            sub_category,
                            coalesce(element_at(key,'Transactions Tracked'),0) AS transaction_tracked,
                            coalesce(element_at(key,'Total Visits'),0) AS total_visits
                            FROM (
                                    SELECT week_commencing_date,
                                        product_pl,
                                        region,
                                        category,
                                        sub_category,
                                        map_agg(metric_name, metric_value) key
                                    FROM   week_aggregation_others
                                    WHERE  metric_name in ('Transactions Tracked','Total Visits')
                                    GROUP BY week_commencing_date,
                                            product_pl,
                                            region,
                                            category,
                                            sub_category
                                )
                            )

                            ) t1
                    CROSS JOIN unnest (
                    array['Conversion Ratio'],
                    array[conversion_ratio]
                    ) t2 (metric_name, metric_value)
                    )
            where coalesce(metric_value,0) <> 0
            and   region IS NOT NULL

            UNION ALL
            SELECT t1.week_commencing_date, t1.product_pl, t1.region,
                    t1.category,
                    t1.sub_category, t2.metric_name, t2.metric_value
            FROM week_aggregation_budget t1
            CROSS JOIN unnest (
            array['Avg Trans Value Budget', 'Gross Transactions Budget', 'Gross Sales Budget'],
            array[ round(gross_sales_budget/coalesce(gross_transactions_budget, 1), 5), gross_transactions_budget, gross_sales_budget ]
            ) t2 (metric_name, metric_value)
            WHERE
                week_commencing_date IS NOT NULL
        ) conversion
        INNER JOIN
            {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
            ON (date(conversion.week_commencing_date) = date(calendar.week_commencing_date) AND calendar.date_scope = 'WEEK')
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    cnv_week
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
/* -- Script Name = conversion_week.sql :: BEGIN -- */
{%- endmacro -%}