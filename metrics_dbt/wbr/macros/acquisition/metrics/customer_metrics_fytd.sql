--Existing sqls keeping for future reference--
{%- macro customer_metrics_fytd() -%}
/* -- Script Name = customer_metrics_fytd.sql :: BEGIN -- */
SELECT
    'FYtD' AS date_scope,
    acquisition.financial_year,
    acquisition.week_number,
    acquisition.week_commencing_date AS year_month_day,
    CAST(current_time AS timestamp) AS last_modified,
    acquisition.week_commencing_date,
    acquisition.product_pl,
    acquisition.region,
    acquisition.category,
    acquisition.sub_category,
    acquisition.metric_name,
    acquisition.metric_value
FROM (
    SELECT
        cst.financial_year, cst.week_number, cst.year_month_day, cst.week_commencing_date,
        cst.product_pl, cst.region, cst.category, cst.sub_category,
        'Cost / Click' AS metric_name,
        IF(clk.metric_value > 0, (cst.metric_value * 1.0) / (clk.metric_value * 1.0), 0) AS metric_value
    FROM (
        SELECT * FROM fytd_aggregation_others
        WHERE week_commencing_date = year_month_day AND metric_name = 'Total Costs'
    ) cst
    INNER JOIN (
        SELECT * FROM fytd_aggregation_others
        WHERE week_commencing_date = year_month_day AND metric_name = 'Total Clicks'
    ) clk
    ON date(cst.week_commencing_date) = date(clk.week_commencing_date)
       AND cst.product_pl = clk.product_pl
       AND cst.region = clk.region
       AND cst.category = clk.category
       AND cst.sub_category = clk.sub_category
) acquisition
/* -- Script Name = customer_metrics_fytd.sql :: END -- */
{%- endmacro -%}