--Existing sqls keeping for future reference--
{%- macro customer_metrics_day() -%}
/* -- Script Name = customer_metrics_day.sql :: BEGIN -- */
WITH
    /* ---
    below CTE is to extract data from "fm_products" for DAY scope (range = current_date - 1),
    focussing on only the requisite attributes that are needed for LTV Segment = Acquisition
    --- */
    fm_products_raw_extract AS
    (
        SELECT
            date(year_month_day) AS year_month_day,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            rm.output_product_pl as product_pl,
            rm.output_region as region,
            /* ------------------------------------------------------------------------------------------------------- -- */
            /* -- will be extended going forward, as per future business case requirements -- */
            CAST(NULL AS VARCHAR) AS category,
            CAST(NULL AS VARCHAR) AS sub_category,
            /* -- bringing in both currency values to allow for GBP projection at UK & EU aggregation level (region = Total) -- */
            m_revenue_total_eur AS total_revenue_eur,
            m_revenue_total_gbp AS total_revenue_gbp,
            m_costs_total_eur AS total_costs_eur,
            m_costs_total_gbp AS total_costs_gbp,
            (m_revenue_total_eur - m_costs_total_eur) AS gross_margin_eur,
            (m_revenue_total_gbp - m_costs_total_gbp) AS gross_margin_gbp
        FROM
            {{ source("bi_dwh", "fm_products") }}
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        inner join 
            {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
            on (coalesce(product_pl_code,'(null)') = rm.input_product_pl and coalesce(order_region_name, '(null)') = rm.input_region)
        /* ------------------------------------------------------------------------------------------------------- -- */
        WHERE
            date(year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND
            order_business_channel_code = '{{ var("acquisition_mart")["business_channel"] }}'
            AND
            order_managed_group_id IN {{ var("acquisition_mart")["managed_group_id"] }} -- include transactions made for both MyCompany as well as PartnerCompany
            AND
            UPPER(product_type_code) IN {{ var("acquisition_mart")["product_type_code"] }}
            AND
            source_system IN {{ var("fm_products")["source_system"] }}
    ),
    /* ---
    below CTE is to aggregate the data from "fm_products" basis of "product_pl" and "region",
    thereby generating all possible combinations of "product_pl" and "region"
    --- */
    fm_products_aggregated AS
    (
        SELECT
            year_month_day AS year_month_day,
			/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
			product_pl,
			region,
			/* ------------------------------------------------------------------------------------------------------- -- */
            COALESCE(category, 'All') AS category,
            COALESCE(sub_category, 'All') AS sub_category,
            /* -- GBP metric values for United Kingdom and Total regions only, and EUR metric values for all other regions -- */
            IF(((product_pl IS NULL AND region IS NULL) OR (product_pl = 'UK' AND region = 'United Kingdom')), SUM(total_revenue_gbp), SUM(total_revenue_eur)) AS total_revenue,
            IF(((product_pl IS NULL AND region IS NULL) OR (product_pl = 'UK' AND region = 'United Kingdom')), SUM(total_costs_gbp), SUM(total_costs_eur)) AS total_costs,
            IF(((product_pl IS NULL AND region IS NULL) OR (product_pl = 'UK' AND region = 'United Kingdom')), SUM(gross_margin_gbp), SUM(gross_margin_eur)) AS gross_margin
        FROM
            fm_products_raw_extract
        GROUP BY
            CUBE -- generate all possible combinations of product_pl and region
            (
                year_month_day,
                product_pl,
                region,
                category,
                sub_category
            )
    ),
    /* ---
    below CTE is to extract data from "marketing_mart" DAY scope (range = current_date - 1),
    focussing on only the requisite attributes that are needed for LTV Segment = Acquisition
    --- */
    marketing_mart_raw_extract AS
    (
        SELECT
            date(activity_date) AS year_month_day,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            rm.output_product_pl as product_pl,
            rm.output_region as region,
            /* ------------------------------------------------------------------------------------------------------- -- */
            /* -- will be extended going forward, as per future business case requirements -- */
            CAST(NULL AS VARCHAR) AS category,
            CAST(NULL AS VARCHAR) AS sub_category,
            /* -- bringing in both currency values to allow for GBP projection at UK & EU aggregation level (region = Total) -- */
            IF(kpi = 'Spend EUR', value) AS marketing_spend_eur,
            IF(kpi = 'Spend GBP', value) AS marketing_spend_gbp
        FROM
            {{ source("bi_dwh", "marketing_mart") }} -- Change this when moving to prod
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        inner join 
            {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
            on (coalesce(pnl_segment,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
        /* ------------------------------------------------------------------------------------------------------- -- */
        WHERE
            date(activity_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}') -- TAG
            AND kpi IN ('Spend EUR', 'Spend GBP')

    ),
    /* ---
    below CTE is to aggregate the data from "marketing_mart" basis of "product_pl" and "region",
    thereby generating all possible combinations of "product_pl" and "region"
    --- */
    marketing_mart_aggregated AS
    (
        SELECT
            year_month_day,
			/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
			product_pl,
			region,
			/* ------------------------------------------------------------------------------------------------------- -- */
            COALESCE(category, 'All') AS category,
            COALESCE(sub_category, 'All') AS sub_category,
            /* -- GBP metric values for United Kingdom and Total regions only, and EUR metric values for all other regions -- */
            IF(((product_pl IS NULL AND region IS NULL) OR (product_pl = 'UK' AND region = 'United Kingdom')), SUM(marketing_spend_gbp), SUM(marketing_spend_eur)) AS marketing_spend
        FROM
            marketing_mart_raw_extract
        GROUP BY
            CUBE -- generate all possible combinations of product_pl and region
            (
                year_month_day,
                product_pl,
                region,
                category,
                sub_category
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
            date_trunc('week', date_add('day', 1, date(person_first_uk_transaction_date))) AS first_uk_transaction_week,
            person_first_eu_transaction_date AS first_eu_transaction_date,
            person_first_uk_transaction_date AS first_uk_transaction_date
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
            order_customer_id AS customer_id,
            date(product_issued_date) AS year_month_day,
            date_trunc('week',date_add('day', 1, date(product_issued_date))) AS product_issued_week,
            product_pl_code AS product_pl,
            order_region_name AS region
        FROM
            {{ source("bi_dwh", "fm_products") }}
        WHERE
            date(year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND
            date(product_issued_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND
            order_business_channel_code = '{{ var("acquisition_mart")["business_channel"] }}'
            AND
            order_managed_group_id IN {{ var("acquisition_mart")["managed_group_id"] }} -- include transactions made for both MyCompany as well as PartnerCompany
            AND
            UPPER(product_type_code) IN {{ var("acquisition_mart")["product_type_code"] }}
            AND
            source_system IN {{ var("fm_products")["source_system"] }}
            AND
            product_gross_sales_flag = 'Y' -- as implemented in "tableau.v_wbr_customer_metrics"
    ),
    /* ---
    below CTE is to join the extracts from "customer_accounts" and "fm_products" created above,
    focussing on only the requisite attributes that are needed for LTV Segment = Acquisition
    --- */
    customer_acquisition_raw_extract AS
    (
        SELECT
            prod.year_month_day AS year_month_day,
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
    below CTE is to aggregate the joined data from "customer_accounts" and "fm_products" basis of "product_pl" and "region",
    thereby generating all possible combinations of "product_pl" and "region"
    --- */
    customer_acquisition_aggregated AS
    (
        SELECT
            year_month_day,
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
            CUBE -- generate all possible combinations of product_pl and region
            (
                year_month_day,
                product_pl,
                region,
                category,
                sub_category
            )
    )
/* ---
deriving metrics for LTV Segment = Acquisition from CTE tables generated above,
joining with calendar data to add date timeline attributes "financial_year" and "week_number"
--- */
SELECT
    'DAY' AS date_scope,
    calendar.financial_year AS financial_year,
    calendar.week_number AS week_number,
    acquisition.year_month_day AS year_month_day,
    CAST(current_time AS timestamp) AS last_modified,
    calendar.week_commencing_date AS week_commencing_date,
    acquisition.product_pl AS product_pl,
    acquisition.region AS region,
    acquisition.category AS category,
    acquisition.sub_category AS sub_category,
    acquisition.metric_name AS metric_name,
    acquisition.metric_value AS metric_value
FROM
(
    SELECT
        fmp.year_month_day,
        fmp.product_pl,
        fmp.region,
        fmp.category,
        fmp.sub_category,
        'GM - PMS' AS metric_name,
        (fmp.gross_margin-mkt.marketing_spend) AS metric_value
    FROM
        fm_products_aggregated fmp
    INNER JOIN
        marketing_mart_aggregated mkt
        ON
        (
            fmp.year_month_day = mkt.year_month_day
            AND
            fmp.product_pl = mkt.product_pl
            AND
            fmp.region = mkt.region
            AND
            fmp.category = mkt.category
            AND
            fmp.sub_category = mkt.sub_category
        )
    UNION ALL
    SELECT
        year_month_day,
        product_pl,
        region,
        category,
        sub_category,
        'Total Revenue' AS metric_name,
        total_revenue AS metric_value
    FROM
        fm_products_aggregated
    UNION ALL
    SELECT
        year_month_day,
        product_pl,
        region,
        category,
        sub_category,
        'Total Costs' AS metric_name,
        total_costs AS metric_value
    FROM
        fm_products_aggregated
    UNION ALL
    SELECT
        year_month_day,
        product_pl,
        region,
        category,
        sub_category,
        'Gross Margin' AS metric_name,
        gross_margin AS metric_value
    FROM
        fm_products_aggregated
    UNION ALL
    SELECT
        year_month_day,
        product_pl,
        region,
        category,
        sub_category,
        'New Customers' AS metric_name,
        new_customers AS metric_value
    FROM
        customer_acquisition_aggregated
    UNION ALL
    SELECT
        year_month_day,
        product_pl,
        region,
        category,
        sub_category,
        'Existing Customers' AS metric_name,
        (active_customers - new_customers) AS metric_value
    FROM
        customer_acquisition_aggregated
    UNION ALL
    SELECT
        year_month_day,
        product_pl,
        region,
        category,
        sub_category,
        'Active Customers' AS metric_name,
        active_customers AS metric_value
    FROM
        customer_acquisition_aggregated
) acquisition
INNER JOIN
    {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
    ON (date(acquisition.year_month_day) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
WHERE
    acquisition.year_month_day IS NOT NULL
    AND
    (
        /* -- associating product_pls with regions -- */
        (
            acquisition.product_pl = 'EU'
            AND
            acquisition.region NOT IN ('Total', 'United Kingdom') -- all EU regions
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
    AND
    acquisition.metric_value IS NOT NULL
/* -- Script Name = customer_metrics_day.sql :: END -- */
{%- endmacro -%}