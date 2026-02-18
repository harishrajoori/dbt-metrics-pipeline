{%- macro acquisition_fytd() -%}
/* -- Script Name = acquisition_fytd.sql :: BEGIN -- */
WITH
    calendar_data AS (
        SELECT
            financial_year,
            week_number,
            week_commencing_date,
            year_month_day
        FROM {{ source("data_metrics_layer", "calendar_dates_lookup") }}
        WHERE date_scope = 'WEEK'
          AND financial_year IN (
                SELECT DISTINCT financial_year
                FROM {{ this }}
                WHERE date_scope = 'WEEK'
                  AND year(date(year_month_day)) BETWEEN year(date('{{ env_var("exe_start_date") }}')) AND year(date('{{ env_var("exe_end_date") }}'))
            )
    ),
    fytd_aggregation_others AS (
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
            SUM(metric_value) OVER (
                PARTITION BY financial_year, product_pl, region, category, sub_category, metric_name
                ORDER BY week_commencing_date
            ) AS metric_value
        FROM {{ this }}
        WHERE date_scope = 'WEEK'
          AND week_commencing_date IN (SELECT DISTINCT week_commencing_date FROM calendar_data)
    ),
    acq_data AS (
        SELECT
            'FYtD' AS date_scope,
            a.financial_year,
            a.week_number,
            a.week_commencing_date AS year_month_day,
            CAST(current_time AS timestamp) AS last_modified,
            a.week_commencing_date,
            a.product_pl,
            a.region,
            a.category,
            a.sub_category,
            a.metric_name,
            a.metric_value
        FROM (
            SELECT
                financial_year, week_number, year_month_day, week_commencing_date,
                product_pl, region, category, sub_category, metric_name, metric_value
            FROM fytd_aggregation_others
            WHERE week_commencing_date = year_month_day
              AND metric_name IN (
                          'Marketing Spend', 'Total Clicks', 'Total Costs', 'Total Impressions', 'Total Installs',
                          'Total Visits', 'Incremental New Customers', 'Incremental Gross Sales', 'Payback Months',
                          'Last Click New Customers', 'Last Click Total Transactions','Last Click Transactions Tracked',
                          'Last Click Net Sales', 'Last Click Marketing Spend','Last Click Gross Sales', 'Total Revenue',
                          'Gross Margin', 'GM - PMS', 'New Customers', 'Existing Customers', 'Active Customers'
            )
            UNION ALL
            SELECT
                t1.financial_year, t1.week_number, t1.year_month_day, t1.week_commencing_date,
                t1.product_pl, t1.region, t1.category, t1.sub_category, t2.metric_name, t2.metric_value
            FROM (
                SELECT
                    financial_year, week_number, year_month_day, week_commencing_date,
                    product_pl, region, category, sub_category,
                    IF(incremental_spend_eur > 0, incremental_gross_sales_eur / incremental_spend_eur, 0) AS incremental_roas,
                    IF(lc_nc > 0, spend / lc_nc, 0) AS cost_per_acquisition,
                    IF(visits > 0, trx_tracked / visits, 0) AS conversion_rate,
                    IF(lc_nc > 0, lc_spend / lc_nc, 0) AS cost_per_acquisition_lc
                FROM (
                    SELECT
                        financial_year, week_number, year_month_day, week_commencing_date,
                        product_pl, region, category, sub_category,
                        COALESCE(element_at(key, 'Incremental Gross Sales EUR'), 0) AS incremental_gross_sales_eur,
                        COALESCE(element_at(key, 'Incremental Spend EUR'), 0) AS incremental_spend_eur,
                        COALESCE(element_at(key, 'Last Click Marketing Spend'), 0) AS lc_spend,
                        COALESCE(element_at(key, 'Marketing Spend'), 0) AS spend,
                        COALESCE(element_at(key, 'Last Click Transactions Tracked'), 0) AS trx_tracked,
                        COALESCE(element_at(key, 'Last Click New Customers'), 0) AS lc_nc,
                        COALESCE(element_at(key, 'Total Visits'), 0) AS visits
                    FROM (
                        SELECT
                            financial_year, week_number, year_month_day, week_commencing_date,
                            product_pl, region, category, sub_category,
                            map_agg(metric_name, metric_value) AS key
                        FROM fytd_aggregation_others
                        WHERE metric_name IN (
                            'Incremental Gross Sales EUR', 'Incremental Spend EUR',
                            'Last Click Marketing Spend', 'Marketing Spend',
                            'Last Click Transactions Tracked', 'Total Visits',
                            'Last Click New Customers'
                        )
                        GROUP BY financial_year, week_number, year_month_day, week_commencing_date,
                                 product_pl, region, category, sub_category
                    )
                )
            ) t1
            CROSS JOIN UNNEST (
                ARRAY['Incremental ROAS', 'CPA', 'CVR', 'LC_CPA'],
                ARRAY[incremental_roas, cost_per_acquisition, conversion_rate, cost_per_acquisition_lc]
            ) t2 (metric_name, metric_value)
            WHERE COALESCE(t2.metric_value, 0) <> 0
        ) a
    ),
    acq_fytd AS (
        SELECT DISTINCT
            date_scope, financial_year, week_number, year_month_day, last_modified, week_commencing_date,
            product_pl, region, category, sub_category, metric_name, metric_value
        FROM acq_data
        UNION
        SELECT
            date_scope, financial_year, week_number, year_month_day, last_modified, week_commencing_date,
            product_pl, region, category, sub_category, metric_name, metric_value
        FROM ({{ customer_metrics_fytd() }})
    )
SELECT DISTINCT *
FROM acq_fytd
WHERE
    financial_year IS NOT NULL AND week_number IS NOT NULL AND year_month_day IS NOT NULL AND
    week_commencing_date IS NOT NULL AND product_pl IS NOT NULL AND region IS NOT NULL AND
    category IS NOT NULL AND sub_category IS NOT NULL AND metric_name IS NOT NULL AND metric_value IS NOT NULL
/* -- Script Name = acquisition_fytd.sql :: END -- */
{%- endmacro -%}