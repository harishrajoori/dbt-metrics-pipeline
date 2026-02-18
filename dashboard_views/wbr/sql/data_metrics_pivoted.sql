CREATE OR REPLACE MATERIALIZED VIEW
    "my_company_data"."dev_data_metrics_layer"."wbr_metrics_pivoted"
WITH
    (
        partitioning = ARRAY['week_commencing_date'] 
    )
AS
WITH
    day_agg AS
    (
        SELECT
            financial_year,
            week_number,
            year_month_day,
            week_commencing_date,
            product_pl,
            region,
            metric[ROW('28-56Day Churned Customers', 'DAY')] AS "DAY_28_56_Day_Churned_Customers",
            metric[ROW('28-56Day New Customers', 'DAY')] AS "DAY_28_56_Day_New_Customers",
            metric[ROW('28-56Day Resurrected Customers', 'DAY')] AS "DAY_28_56_Day_Resurrected_Customers",
            metric[ROW('28-56Day Retained Customers', 'DAY')] AS "DAY_28_56_Day_Retained_Customers",
            metric[ROW('Active Customers', 'DAY')] AS "DAY_Active_Customers",
            metric[ROW('Avg Trans Value', 'DAY')] AS "DAY_Avg_Trans_Value",
            metric[ROW('Conversion Ratio', 'DAY')] AS "DAY_Conversion_Ratio",
            metric[ROW('Cost / Click', 'DAY')] AS "DAY_Cost_Per_Click",
            metric[ROW('Existing Customers', 'DAY')] AS "DAY_Existing_Customers",
            metric[ROW('Fee Revenue / Transaction', 'DAY')] AS "DAY_Fee_Revenue_Per_Transaction",
            metric[ROW('Fee Revenue', 'DAY')] AS "DAY_Fee_Revenue",
            metric[ROW('GM - PMS', 'DAY')] AS "DAY_GM_Minus_PMS",
            metric[ROW('Gross Margin', 'DAY')] AS "DAY_Gross_Margin",
            metric[ROW('Gross Sales', 'DAY')] AS "DAY_Gross_Sales",
            metric[ROW('Gross Transactions', 'DAY')] AS "DAY_Gross_Transactions",
            metric[ROW('Marketing Spend', 'DAY')] AS "DAY_Marketing_Spend",
            metric[ROW('Net Sales', 'DAY')] AS "DAY_Net_Sales",
            metric[ROW('New Customers', 'DAY')] AS "DAY_New_Customers",
            IF(region <> 'UK>EU', metric[ROW('Non-Fee Revenue / Visit', 'DAY')], NULL) AS "DAY_Non_Fee_Revenue_Per_Visit",
            metric[ROW('Non-Fee Revenue', 'DAY')] AS "DAY_Non_Fee_Revenue",
            metric[ROW('Total Clicks', 'DAY')] AS "DAY_Total_Clicks",
            metric[ROW('Total Costs', 'DAY')] AS "DAY_Total_Costs",
            metric[ROW('Total Impressions', 'DAY')] AS "DAY_Total_Impressions",
            metric[ROW('Total Refunds', 'DAY')] AS "DAY_Total_Refunds",
            metric[ROW('Total Revenue', 'DAY')] AS "DAY_Total_Revenue",
            metric[ROW('Total Visits', 'DAY')] AS "DAY_Total_Visits",
            metric[ROW('Transactions Tracked', 'DAY')] AS "DAY_Transactions_Tracked"
        FROM
        (
            SELECT DISTINCT
                date_scope,
                financial_year,
                week_number,
                year_month_day,
                week_commencing_date,
                product_pl,
                region,
                map_agg(ROW(metric_name, date_scope), metric_value) as metric
            FROM
                "dev_data_metrics_layer"."wbr_overview_status"
            WHERE
                (date_scope = 'DAY' AND metric_name NOT LIKE '%Budget%')
            AND
                date(last_modified) = date('2000-01-01')
            GROUP BY
                1,2,3,4,5,6,7
        )
    ),
    week_agg AS 
    (
        SELECT
            financial_year,
            week_number,
            year_month_day,
            week_commencing_date,
            product_pl,
            region,
            metric[ROW('28-56Day Churned Customers', 'WEEK')] AS "WEEK_28_56_Day_Churned_Customers",
            metric[ROW('28-56Day New Customers', 'WEEK')] AS "WEEK_28_56_Day_New_Customers",
            metric[ROW('28-56Day Resurrected Customers', 'WEEK')] AS "WEEK_28_56_Day_Resurrected_Customers",
            metric[ROW('28-56Day Retained Customers', 'WEEK')] AS "WEEK_28_56_Day_Retained_Customers",
            metric[ROW('Active Customers', 'WEEK')] AS "WEEK_Active_Customers",
            metric[ROW('Avg Trans Value', 'WEEK')] AS "WEEK_Avg_Trans_Value",
            metric[ROW('Conversion Ratio', 'WEEK')] AS "WEEK_Conversion_Ratio",
            metric[ROW('Cost / Click', 'WEEK')] AS "WEEK_Cost_Per_Click",
            metric[ROW('Existing Customers', 'WEEK')] AS "WEEK_Existing_Customers",
            metric[ROW('Fee Revenue / Transaction', 'WEEK')] AS "WEEK_Fee_Revenue_Per_Transaction",
            metric[ROW('Fee Revenue', 'WEEK')] AS "WEEK_Fee_Revenue",
            metric[ROW('GM - PMS', 'WEEK')] AS "WEEK_GM_Minus_PMS",
            metric[ROW('Gross Margin', 'WEEK')] AS "WEEK_Gross_Margin",
            metric[ROW('Gross Sales', 'WEEK')] AS "WEEK_Gross_Sales",
            metric[ROW('Gross Transactions', 'WEEK')] AS "WEEK_Gross_Transactions",
            metric[ROW('Marketing Spend', 'WEEK')] AS "WEEK_Marketing_Spend",
            metric[ROW('Net Sales', 'WEEK')] AS "WEEK_Net_Sales",
            metric[ROW('New Customers', 'WEEK')] AS "WEEK_New_Customers",
            IF(region <> 'UK>EU', metric[ROW('Non-Fee Revenue / Visit', 'WEEK')], NULL) AS "WEEK_Non_Fee_Revenue_Per_Visit",
            metric[ROW('Non-Fee Revenue', 'WEEK')] AS "WEEK_Non_Fee_Revenue",
            metric[ROW('Total Clicks', 'WEEK')] AS "WEEK_Total_Clicks",
            metric[ROW('Total Costs', 'WEEK')] AS "WEEK_Total_Costs",
            metric[ROW('Total Impressions', 'WEEK')] AS "WEEK_Total_Impressions",
            metric[ROW('Total Refunds', 'WEEK')] AS "WEEK_Total_Refunds",
            metric[ROW('Total Revenue', 'WEEK')] AS "WEEK_Total_Revenue",
            metric[ROW('Total Visits', 'WEEK')] AS "WEEK_Total_Visits",
            metric[ROW('Transactions Tracked', 'WEEK')] AS "WEEK_Transactions_Tracked"
        FROM
        (
            SELECT DISTINCT
                date_scope,
                financial_year,
                week_number,
                year_month_day,
                week_commencing_date,
                product_pl,
                region,
                map_agg(ROW(metric_name, date_scope), metric_value) as metric
            FROM
                "dev_data_metrics_layer"."wbr_overview_status"
            WHERE
                (date_scope = 'WEEK' AND metric_name NOT LIKE '%Budget%')
            AND
                date(last_modified) = date('2000-01-01')
            GROUP BY
                1,2,3,4,5,6,7
        )
    ),
    fytd_agg AS 
    (
        SELECT
            financial_year,
            week_number,
            year_month_day,
            week_commencing_date,
            product_pl,
            region,
            metric[ROW('28-56Day Churned Customers', 'FYtD')] AS "FYtD_28_56_Day_Churned_Customers",
            metric[ROW('28-56Day New Customers', 'FYtD')] AS "FYtD_28_56_Day_New_Customers",
            metric[ROW('28-56Day Resurrected Customers', 'FYtD')] AS "FYtD_28_56_Day_Resurrected_Customers",
            metric[ROW('28-56Day Retained Customers', 'FYtD')] AS "FYtD_28_56_Day_Retained_Customers",
            metric[ROW('Active Customers', 'FYtD')] AS "FYtD_Active_Customers",
            metric[ROW('Avg Trans Value', 'FYtD')] AS "FYtD_Avg_Trans_Value",
            metric[ROW('Conversion Ratio', 'FYtD')] AS "FYtD_Conversion_Ratio",
            metric[ROW('Cost / Click', 'FYtD')] AS "FYtD_Cost_Per_Click",
            metric[ROW('Existing Customers', 'FYtD')] AS "FYtD_Existing_Customers",
            metric[ROW('Fee Revenue / Transaction', 'FYtD')] AS "FYtD_Fee_Revenue_Per_Transaction",
            metric[ROW('Fee Revenue', 'FYtD')] AS "FYtD_Fee_Revenue",
            metric[ROW('GM - PMS', 'FYtD')] AS "FYtD_GM_Minus_PMS",
            metric[ROW('Gross Margin', 'FYtD')] AS "FYtD_Gross_Margin",
            metric[ROW('Gross Sales', 'FYtD')] AS "FYtD_Gross_Sales",
            metric[ROW('Gross Transactions', 'FYtD')] AS "FYtD_Gross_Transactions",
            metric[ROW('Marketing Spend', 'FYtD')] AS "FYtD_Marketing_Spend",
            metric[ROW('Net Sales', 'FYtD')] AS "FYtD_Net_Sales",
            metric[ROW('New Customers', 'FYtD')] AS "FYtD_New_Customers",
            IF(region <> 'UK>EU', metric[ROW('Non-Fee Revenue / Visit', 'FYtD')], NULL) AS "FYtD_Non_Fee_Revenue_Per_Visit",
            metric[ROW('Non-Fee Revenue', 'FYtD')] AS "FYtD_Non_Fee_Revenue",
            metric[ROW('Total Clicks', 'FYtD')] AS "FYtD_Total_Clicks",
            metric[ROW('Total Costs', 'FYtD')] AS "FYtD_Total_Costs",
            metric[ROW('Total Impressions', 'FYtD')] AS "FYtD_Total_Impressions",
            metric[ROW('Total Refunds', 'FYtD')] AS "FYtD_Total_Refunds",
            metric[ROW('Total Revenue', 'FYtD')] AS "FYtD_Total_Revenue",
            metric[ROW('Total Visits', 'FYtD')] AS "FYtD_Total_Visits",
            metric[ROW('Transactions Tracked', 'FYtD')] AS "FYtD_Transactions_Tracked"
        FROM
        (
            SELECT DISTINCT
                date_scope,
                financial_year,
                week_number,
                year_month_day,
                week_commencing_date,
                product_pl,
                region,
                map_agg(ROW(metric_name, date_scope), metric_value) as metric
            FROM
                "dev_data_metrics_layer"."wbr_overview_status"
            WHERE
                (date_scope = 'FYtD' AND metric_name NOT LIKE '%Budget%')
            AND
                date(last_modified) = date('2000-01-01')
            GROUP BY
                1,2,3,4,5,6,7
        )
    )
SELECT
    d.financial_year,
    d.week_number,
    d.year_month_day,
    d.week_commencing_date,
    d.product_pl,
    d.region,
    d."DAY_28_56_Day_Churned_Customers",
    d."DAY_28_56_Day_New_Customers",
    d."DAY_28_56_Day_Resurrected_Customers",
    d."DAY_28_56_Day_Retained_Customers",
    d."DAY_Active_Customers",
    d."DAY_Avg_Trans_Value",
    d."DAY_Conversion_Ratio",
    d."DAY_Cost_Per_Click",
    d."DAY_Existing_Customers",
    d."DAY_Fee_Revenue_Per_Transaction",
    d."DAY_Fee_Revenue",
    d."DAY_GM_Minus_PMS",
    d."DAY_Gross_Margin",
    d."DAY_Gross_Sales",
    d."DAY_Gross_Transactions",
    d."DAY_Marketing_Spend",
    d."DAY_Net_Sales",
    d."DAY_New_Customers",
    d."DAY_Non_Fee_Revenue_Per_Visit",
    d."DAY_Non_Fee_Revenue",
    d."DAY_Total_Clicks",
    d."DAY_Total_Costs",
    d."DAY_Total_Impressions",
    d."DAY_Total_Refunds",
    d."DAY_Total_Revenue",
    d."DAY_Total_Visits",
    d."DAY_Transactions_Tracked",
    w."WEEK_28_56_Day_Churned_Customers",
    w."WEEK_28_56_Day_New_Customers",
    w."WEEK_28_56_Day_Resurrected_Customers",
    w."WEEK_28_56_Day_Retained_Customers",
    w."WEEK_Active_Customers",
    w."WEEK_Avg_Trans_Value",
    w."WEEK_Conversion_Ratio",
    w."WEEK_Cost_Per_Click",
    w."WEEK_Existing_Customers",
    w."WEEK_Fee_Revenue_Per_Transaction",
    w."WEEK_Fee_Revenue",
    w."WEEK_GM_Minus_PMS",
    w."WEEK_Gross_Margin",
    w."WEEK_Gross_Sales",
    w."WEEK_Gross_Transactions",
    w."WEEK_Marketing_Spend",
    w."WEEK_Net_Sales",
    w."WEEK_New_Customers",
    w."WEEK_Non_Fee_Revenue_Per_Visit",
    w."WEEK_Non_Fee_Revenue",
    w."WEEK_Total_Clicks",
    w."WEEK_Total_Costs",
    w."WEEK_Total_Impressions",
    w."WEEK_Total_Refunds",
    w."WEEK_Total_Revenue",
    w."WEEK_Total_Visits",
    w."WEEK_Transactions_Tracked",
    f."FYtD_28_56_Day_Churned_Customers",
    f."FYtD_28_56_Day_New_Customers",
    f."FYtD_28_56_Day_Resurrected_Customers",
    f."FYtD_28_56_Day_Retained_Customers",
    f."FYtD_Active_Customers",
    f."FYtD_Avg_Trans_Value",
    f."FYtD_Conversion_Ratio",
    f."FYtD_Cost_Per_Click",
    f."FYtD_Existing_Customers",
    f."FYtD_Fee_Revenue_Per_Transaction",
    f."FYtD_Fee_Revenue",
    f."FYtD_GM_Minus_PMS",
    f."FYtD_Gross_Margin",
    f."FYtD_Gross_Sales",
    f."FYtD_Gross_Transactions",
    f."FYtD_Marketing_Spend",
    f."FYtD_Net_Sales",
    f."FYtD_New_Customers",
    f."FYtD_Non_Fee_Revenue_Per_Visit",
    f."FYtD_Non_Fee_Revenue",
    f."FYtD_Total_Clicks",
    f."FYtD_Total_Costs",
    f."FYtD_Total_Impressions",
    f."FYtD_Total_Refunds",
    f."FYtD_Total_Revenue",
    f."FYtD_Total_Visits",
    f."FYtD_Transactions_Tracked"
FROM 
    day_agg d
LEFT JOIN 
    week_agg w
    ON (d.financial_year = w.financial_year AND d.week_number = w.week_number AND d.year_month_day = w.week_commencing_date AND d.week_commencing_date = w.week_commencing_date AND d.product_pl = w.product_pl AND d.region = w.region)
LEFT JOIN 
    fytd_agg f
    ON (d.financial_year = f.financial_year AND d.week_number = f.week_number AND d.year_month_day = f.week_commencing_date AND d.week_commencing_date = f.week_commencing_date AND d.product_pl = f.product_pl AND d.region = f.region)
ORDER BY
    1,2,3,4,5,6,7;
