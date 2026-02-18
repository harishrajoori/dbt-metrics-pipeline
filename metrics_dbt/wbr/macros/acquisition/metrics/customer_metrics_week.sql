--Existing sqls keeping for future reference--
{%- macro customer_metrics_week() -%}
/* -- Script Name = customer_metrics_week.sql :: BEGIN -- */
WITH
    /* ---
    below CTE extracts all the year_month_day dates which correspond
    to the week_commencing_dates that fall between the start and end dates
    --- */
    calendar_data AS
    (
        SELECT
            week_commencing_date,
            year_month_day
        FROM
            {{ source("data_metrics_layer", "calendar_dates_lookup") }}
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
    below CTE is to extract customers data from "customer_accounts",
    along-with their first_transaction_region and first_transaction_week
    --- */
    customer_transactions_raw_extract AS
    (
        /* -- below is for EU transactions only -- */
        SELECT
            person_id AS person_id,
            customer_id AS customer_id,
            person_first_eu_transaction_order_region AS first_eu_transaction_region,
            person_first_transaction_order_region AS first_transaction_region,
            date_trunc('week', date_add('day', 1, date(person_first_eu_transaction_date))) AS first_eu_transaction_week,
            date_trunc('week', date_add('day', 1, date(person_first_uk_transaction_date))) AS first_uk_transaction_week
        FROM
            {{ source("bi_dwh", "customer_accounts") }}
        WHERE
            managed_group_id IN {{ var("acquisition_mart")["managed_group_id"] }} -- include transactions made for both MyCompany as well as PartnerCompany
        AND
            segment = '{{ var("acquisition_mart")["segment"] }}' -- only extract the most recent record and not the historical ones
    ),
    /* ---
    below CTE is to extract products data from "fm_products",
    along-with their product_issued_date and product_issued_week
    --- */
    products_issued_raw_extract AS
    (
        SELECT
            date(fmp.product_issued_date) AS year_month_day,
            cal.week_commencing_date,
            fmp.product_pl_code AS product_pl,
            fmp.order_region_name AS region,
            fmp.order_customer_id AS customer_id,
            date_trunc('week',date_add('day', 1, date(fmp.product_issued_date))) AS product_issued_week
        FROM
            {{ source("bi_dwh", "fm_products") }} fmp
        INNER JOIN
            calendar_data cal
            ON (date(fmp.year_month_day) = cal.year_month_day AND date(fmp.product_issued_date) = cal.year_month_day)
        WHERE
            (
                fmp.order_business_channel_code = '{{ var("acquisition_mart")["business_channel"] }}'
                AND
                fmp.order_managed_group_id IN {{ var("acquisition_mart")["managed_group_id"] }} -- include transactions made for both MyCompany as well as PartnerCompany
                AND
                UPPER(fmp.product_type_code) IN ('TRAVEL', 'SEASONS', 'SEASONS_FLEXI','RAILCARD')
                AND
                source_system IN {{ var("fm_products")["source_system"] }}
            )
    ),
    /* ---
    below CTE is to join the extracts from "customer_accounts" and "fm_products" created above,
    focussing on only the requisite attributes that are needed for LTV Segment = Acquisition
    --- */
    customer_acquisition_raw_extract AS
    (
        SELECT
            prod.week_commencing_date AS week_commencing_date,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            rm.output_product_pl as product_pl,
            rm.output_region as region,
            /* ------------------------------------------------------------------------------------------------------- -- */
            /* -- will be extended going forward, as per future business case requirements -- */
            'TBD' AS category,
            'TBD' AS sub_category,
            cust.person_id AS person_id,
            CASE
                WHEN prod.product_pl = 'UK'
                THEN IF(cust.first_uk_transaction_week = prod.product_issued_week, 'New', 'Existing')
                ELSE IF(cust.first_eu_transaction_week = prod.product_issued_week AND cust.first_eu_transaction_region = prod.region, 'New', 'Existing')
            END AS new_existing_flag
        FROM
            customer_transactions_raw_extract cust
        LEFT JOIN
            products_issued_raw_extract prod
            ON (cust.customer_id = prod.customer_id)
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        inner join 
            {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
            on (coalesce(prod.product_pl,'(null)') = rm.input_product_pl and coalesce(prod.region, '(null)') = rm.input_region)
        /* ------------------------------------------------------------------------------------------------------- -- */
    ),
    /* ---
    below CTE generates WEEK level aggregations for customer metrics
    --- */
    week_aggregation_customers AS
    (
        SELECT
            week_commencing_date,
			/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
			product_pl,
			region,
			/* ------------------------------------------------------------------------------------------------------- -- */
            COALESCE(category, 'All') AS category,
            COALESCE(sub_category, 'All') AS sub_category,
            COUNT(DISTINCT IF(new_existing_flag = 'New', person_id)) AS new_customers,
            COUNT(DISTINCT IF(new_existing_flag = 'Existing', person_id)) AS existing_customers,
            COUNT(DISTINCT IF(new_existing_flag IN ('New', 'Existing'), person_id)) AS active_customers
        FROM
            customer_acquisition_raw_extract
        GROUP BY
            /* -- grouping with focus on week_commencing_date to generate WEEK level aggregation -- */
            CUBE -- generate all possible combinations of product_pl and region
            (
                week_commencing_date,
                product_pl,
                region,
                category,
                sub_category
            )
    )
    /* ---
    Moved Budget metrics to Supply mart
    --- */
SELECT
    'WEEK' AS date_scope,
    calendar.financial_year AS financial_year,
    calendar.week_number AS week_number,
    acquisition.week_commencing_date AS year_month_day,
    CAST(current_time AS timestamp) AS last_modified,
    acquisition.week_commencing_date AS week_commencing_date,
    acquisition.product_pl AS product_pl,
    acquisition.region AS region,
    acquisition.category AS category,
    acquisition.sub_category AS sub_category,
    acquisition.metric_name AS metric_name,
    acquisition.metric_value AS metric_value
FROM
(
    SELECT
        week_commencing_date,
        product_pl,
        region,
        category,
        sub_category,
        'New Customers' AS metric_name,
        new_customers AS metric_value
    FROM
        week_aggregation_customers
    UNION ALL
    SELECT
        week_commencing_date,
        product_pl,
        region,
        category,
        sub_category,
        'Existing Customers' AS metric_name,
        (active_customers - new_customers)  AS metric_value
    FROM
        week_aggregation_customers
    UNION ALL
    SELECT
        week_commencing_date,
        product_pl,
        region,
        category,
        sub_category,
        'Active Customers' AS metric_name,
        active_customers AS metric_value
    FROM
        week_aggregation_customers
    UNION ALL
    SELECT
        cst.week_commencing_date,
        cst.product_pl,
        cst.region,
        cst.category,
        cst.sub_category,
        'Cost / Click' AS metric_name,
        IF(clk.metric_value > 0, ((cst.metric_value*1.0000000)/(clk.metric_value*1.0000000)), 0) AS metric_value
    FROM
        week_aggregation_others cst
    INNER JOIN
        week_aggregation_others clk
        ON
        (
            date(cst.week_commencing_date) = date(clk.week_commencing_date)
            AND
            cst.product_pl = clk.product_pl
            AND
            cst.region = clk.region
            AND
            cst.category = clk.category
            AND
            cst.sub_category = clk.sub_category
            AND
            cst.metric_name = 'Total Costs'
            AND
            clk.metric_name = 'Total Clicks'
        )
) acquisition
INNER JOIN
    {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
    ON (date(acquisition.week_commencing_date) = date(calendar.week_commencing_date) AND calendar.date_scope = 'WEEK')
WHERE
(
    acquisition.week_commencing_date IS NOT NULL
    AND
    (
        /* -- associating product_pls with regions -- */
        (
            acquisition.product_pl = 'EU'
            AND
            acquisition.region IN  ('France', 'Germany', 'Inbound', 'International', 'Italy', 'RoE', 'Spain', 'UK>EU') -- all EU regions
        )
        OR
        (
            acquisition.product_pl = 'UK'
            AND
            acquisition.region = 'United Kingdom' -- all UK regions
        )
        OR
        (
            acquisition.product_pl = 'UK & EU'
            AND
            acquisition.region = 'Total' -- all UK & EU regions
        )
    )
    AND
    acquisition.category IS NOT NULL
    AND
    acquisition.sub_category IS NOT NULL
)
/* -- Script Name = customer_metrics_week.sql :: END -- */
{%- endmacro -%}