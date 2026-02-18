{%- macro anaplan_week() -%}
/* -- Script Name = anaplan_week.sql :: BEGIN -- */
WITH
    /* ---
    below CTE extracts all the year_month_day dates which correspond
    to the week_commencing_dates
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
            )
    ),
    /* ---
    below CTE generates WEEK level aggregations for all metrics
    --- */
    week_aggregation_others AS
    (
        SELECT
            version,
            week_commencing_date,
            week_in_fin_year,
            region,
            SUM(CASE WHEN gross_sales_budget = 0 THEN 0 ELSE 1 END) AS num_available_days,
            SUM(gross_sales_budget) AS gross_sales_budget,
            SUM(net_sales_budget) AS net_sales_budget,
            SUM(new_customers_budget) AS new_customers_budget,
            SUM(gross_transactions_budget) AS gross_transactions_budget,
            SUM(marketing_spend_budget) AS marketing_spend_budget,
            SUM(total_revenue_budget) AS total_revenue_budget,
            SUM(total_costs_budget) AS total_costs_budget
        FROM {{ this }}
        WHERE date_scope = 'DAY'
        AND week_commencing_date IN
        (
            SELECT DISTINCT week_commencing_date
            FROM calendar_data
        )
        GROUP BY 1,2,3,4
    )
SELECT
    'WEEK' AS date_scope,
    ab.version,
    ab.week_commencing_date as year_month_day,
    ab.week_in_fin_year,
    ab.week_commencing_date,
    ab.region,
    CAST(current_time AS timestamp) AS last_modified,
    gross_sales_budget * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) as gross_sales_budget,
    net_sales_budget * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) as net_sales_budget,
    new_customers_budget * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) as new_customers_budget,
    gross_transactions_budget * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) as gross_transactions_budget,
    IF(gross_transactions_budget > 0, ((gross_sales_budget * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) *1.00)/(gross_transactions_budget*1.00)), 0) as average_transaction_value_budget,
    marketing_spend_budget * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) as marketing_spend_budget,
    total_revenue_budget * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) as total_revenue_budget,
    total_costs_budget * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) as total_costs_budget,
    (total_revenue_budget + total_costs_budget) * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) as gross_margin_budget,
    (total_revenue_budget + total_costs_budget - marketing_spend_budget) * (CASE WHEN num_available_days = 7 THEN 1 ELSE 0 END) as gm_minus_pms_budget
FROM
    week_aggregation_others ab
INNER JOIN
    {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
    ON (date(ab.week_commencing_date) = date(calendar.week_commencing_date) AND calendar.date_scope = 'WEEK')
/* -- Script Name = anaplan_week.sql :: END -- */
{%- endmacro -%}
