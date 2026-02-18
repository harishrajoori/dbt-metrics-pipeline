{%- macro transaction_metrics() -%}
/* -- Script Name = 301_transaction_metrics.sql :: BEGIN -- */
SELECT
    year_month_day
    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
    , product_pl
    , region
    /* ------------------------------------------------------------------------------------------------------- -- */
    , 'Trx' AS category
--    , CASE
--        WHEN sub_category IS NULL THEN NULL
--        WHEN sub_category = 'All' THEN 'All'
--        ELSE 'Trx'
--    END AS category
    , sub_category
    , metric_name
    , ROUND(
        CASE
            -- Booking Fee Metrics
            WHEN sub_category = 'Booking Fee' AND metric_name = 'Number of Tickets' THEN SUM(booking_fee_number_of_tickets)
            WHEN sub_category = 'Booking Fee' AND metric_name = 'Percent of Tickets' THEN SUM(CAST(booking_fee_number_of_tickets AS DOUBLE)) / SUM(CAST(total_number_of_tickets AS DOUBLE))
            WHEN sub_category = 'Booking Fee' AND metric_name = 'Take Rate' THEN
                IF( product_pl = 'UK' OR product_pl IS NULL,
                    SUM(CAST(booking_fee_revenue_gbp AS DOUBLE)) / SUM(CAST(net_sales_amount_gbp AS DOUBLE)),
                    SUM(CAST(booking_fee_revenue_eur AS DOUBLE)) / SUM(CAST(net_sales_amount_eur AS DOUBLE))
                )
            WHEN sub_category = 'Booking Fee' AND metric_name = 'Revenue' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(booking_fee_revenue_gbp), SUM(booking_fee_revenue_eur))

            -- Refund Fee Metrics

            -- Refund fee revenue removed for 2023, Jan
            WHEN sub_category = 'Refund Fee' AND metric_name IN ('Take Rate', 'Revenue') AND product_pl = 'EU'
            AND DATE(year_month_day) BETWEEN DATE('2023-01-01') AND DATE('2023-01-31') THEN NULL
            -----

            WHEN sub_category = 'Refund Fee' AND metric_name = 'Number of Tickets' THEN SUM(refund_fee_number_of_tickets)
            WHEN sub_category = 'Refund Fee' AND metric_name = 'Percent of Tickets' THEN SUM(CAST(refund_fee_number_of_tickets AS DOUBLE)) / SUM(CAST(total_number_of_tickets AS DOUBLE))
            WHEN sub_category = 'Refund Fee' AND metric_name = 'Take Rate' THEN
                IF( product_pl = 'UK' OR product_pl IS NULL,
                    SUM(CAST(refund_fee_revenue_gbp AS DOUBLE)) / SUM(CAST(net_sales_amount_gbp AS DOUBLE)),
                    SUM(CAST(refund_fee_revenue_eur AS DOUBLE)) / SUM(CAST(net_sales_amount_eur AS DOUBLE))
                )
            WHEN sub_category = 'Refund Fee' AND metric_name = 'Revenue' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(refund_fee_revenue_gbp), SUM(refund_fee_revenue_eur))

            -- COJ Fee Metrics
            WHEN sub_category = 'COJ Fee' AND metric_name = 'Number of Tickets' THEN SUM(coj_fee_number_of_tickets)
            WHEN sub_category = 'COJ Fee' AND metric_name = 'Percent of Tickets' THEN SUM(CAST(coj_fee_number_of_tickets AS DOUBLE)) / SUM(CAST(total_number_of_tickets AS DOUBLE))
            WHEN sub_category = 'COJ Fee' AND metric_name = 'Take Rate' THEN
                IF( product_pl = 'UK' OR product_pl IS NULL,
                    SUM(CAST(coj_fee_revenue_gbp AS DOUBLE)) / SUM(CAST(net_sales_amount_gbp AS DOUBLE)),
                    SUM(CAST(coj_fee_revenue_eur AS DOUBLE)) / SUM(CAST(net_sales_amount_eur AS DOUBLE))
                )
            WHEN sub_category = 'COJ Fee' AND metric_name = 'Revenue' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(coj_fee_revenue_gbp), SUM(coj_fee_revenue_eur))

            -- Commission Metrics
            WHEN sub_category = 'Commission' AND metric_name = 'Take Rate' THEN
                IF( product_pl = 'UK' OR product_pl IS NULL,
                    SUM(CAST(commission_revenue_gbp AS DOUBLE)) / SUM(CAST(net_sales_amount_gbp AS DOUBLE)),
                    SUM(CAST(commission_revenue_eur AS DOUBLE)) / SUM(CAST(net_sales_amount_eur AS DOUBLE))
                )
            WHEN sub_category = 'Commission' AND metric_name = 'Revenue' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(commission_revenue_gbp), SUM(commission_revenue_eur))

            -- Ancillary Metrics
            WHEN sub_category = 'Ancillary' AND metric_name = 'Take Rate' THEN
                IF( product_pl = 'UK' OR product_pl IS NULL,
                    SUM(CAST(insurance_commission_revenue_gbp AS DOUBLE)) / SUM(CAST(net_sales_amount_gbp AS DOUBLE)),
                    SUM(CAST(insurance_commission_revenue_eur AS DOUBLE)) / SUM(CAST(net_sales_amount_eur AS DOUBLE))
                )
            WHEN sub_category = 'Ancillary' AND metric_name = 'Revenue' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(insurance_commission_revenue_gbp), SUM(insurance_commission_revenue_eur))

            -- MCP Metrics
            WHEN sub_category = 'MCP' AND metric_name = 'Number of Tickets' THEN SUM(mcp_number_of_tickets)
            WHEN sub_category = 'MCP' AND metric_name = 'Percent of Tickets' THEN SUM(CAST(mcp_number_of_tickets AS DOUBLE)) / SUM(CAST(total_number_of_tickets AS DOUBLE))
            WHEN sub_category = 'MCP' AND metric_name = 'Take Rate' THEN
                IF( product_pl = 'UK' OR product_pl IS NULL,
                    SUM(CAST(mcp_revenue_gbp AS DOUBLE)) / SUM(CAST(net_sales_amount_gbp AS DOUBLE)),
                    SUM(CAST(mcp_revenue_eur AS DOUBLE)) / SUM(CAST(net_sales_amount_eur AS DOUBLE))
                )
            WHEN sub_category = 'MCP' AND metric_name = 'Revenue' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(mcp_revenue_gbp), SUM(mcp_revenue_eur))

            -- Net sale
            WHEN sub_category = 'Transaction' AND metric_name = 'Total Number of Tickets' THEN SUM(total_number_of_tickets)
            WHEN sub_category = 'Transaction' AND metric_name = 'Net Sale' THEN
                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(net_sales_amount_gbp), SUM(net_sales_amount_eur))

            -- WBR METRICS
--            WHEN sub_category = 'All' AND metric_name = 'Total Revenue' THEN
--                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(total_revenue_gbp), SUM(total_revenue_eur))
--            WHEN sub_category = 'All' AND metric_name = 'Fee Revenue' THEN
--                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(fee_revenue_gbp), SUM(fee_revenue_eur))
--            WHEN sub_category = 'All' AND metric_name = 'Non-Fee Revenue' THEN
--                IF(product_pl = 'UK' OR product_pl IS NULL, SUM(non_fee_revenue_gbp), SUM(non_fee_revenue_gbp))
--            WHEN sub_category = 'All' AND metric_name = 'Gross Transactions' THEN COUNT(DISTINCT transaction_order_id)
--            WHEN sub_category = 'All' AND metric_name = 'Fee Revenue / Transaction' THEN
--                IF( product_pl = 'UK' OR product_pl IS NULL,
--                    SUM(CAST(fee_revenue_gbp AS DOUBLE)) / CAST(COUNT(DISTINCT transaction_order_id) AS DOUBLE),
--                    SUM(CAST(fee_revenue_eur AS DOUBLE)) / CAST(COUNT(DISTINCT transaction_order_id) AS DOUBLE)
--                )
        END, 4) AS metric_value
FROM (
        {{ fm_products_extract() }}
    ) fm_products
CROSS JOIN UNNEST(
        ARRAY[
            ROW('Booking Fee', 'Number of Tickets'),
            ROW('Booking Fee', 'Percent of Tickets'),
            ROW('Booking Fee', 'Take Rate'),
            ROW('Booking Fee', 'Revenue'),
            ROW('Refund Fee', 'Number of Tickets'),
            ROW('Refund Fee', 'Percent of Tickets'),
            ROW('Refund Fee', 'Take Rate'),
            ROW('Refund Fee', 'Revenue'),
            ROW('COJ Fee', 'Number of Tickets'),
            ROW('COJ Fee', 'Percent of Tickets'),
            ROW('COJ Fee', 'Take Rate'),
            ROW('COJ Fee', 'Revenue'),
            ROW('Commission', 'Take Rate'),
            ROW('Commission', 'Revenue'),
            ROW('Ancillary', 'Take Rate'),
            ROW('Ancillary', 'Revenue'),
            ROW('MCP', 'Number of Tickets'),
            ROW('MCP', 'Percent of Tickets'),
            ROW('MCP', 'Take Rate'),
            ROW('MCP', 'Revenue'),
            ROW('Transaction', 'Total Number of Tickets'),
            ROW('Transaction', 'Net Sale')
--            ROW('All', 'Total Revenue'),
--            ROW('All', 'Fee Revenue'),
--            ROW('All', 'Non-Fee Revenue'),
--            ROW('All', 'Gross Transactions'),
--            ROW('All', 'Fee Revenue / Transaction')
        ]
    ) AS t(sub_category, metric_name)
GROUP BY CUBE(year_month_day, product_pl, region, metric_name, sub_category)
/* -- Script Name = 301_transaction_metrics.sql :: END -- */
{%- endmacro -%}