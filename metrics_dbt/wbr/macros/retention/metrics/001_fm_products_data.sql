{%- macro fm_products_data() -%}
/* -- Script Name = 001_fm_products_data.sql :: BEGIN -- */
SELECT
    date(year_month_day) AS year_month_day
    , order_customer_id
    , order_business_channel_code
    , product_travel_classification_name
    , fare_train_classification_name_longest_duration
    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
    , rm.output_product_pl as product_pl
    , rm.output_region as region
    /* ------------------------------------------------------------------------------------------------------- -- */
    , IF(product_gross_sales_flag = 'Y' AND record_type = 'SALES', order_id) AS transaction_order_id
    , m_net_sales_amount_gbp
    , m_net_sales_amount_eur
FROM
    {{ source("bi_dwh", "fm_products") }}
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
inner join 
    {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
    on (coalesce(product_pl_code,'(null)') = rm.input_product_pl and coalesce(order_region_name, '(null)') = rm.input_region)
/* ------------------------------------------------------------------------------------------------------- -- */
WHERE
    date(year_month_day) BETWEEN DATE_ADD('day', -45, date('{{ env_var("exe_start_date") }}')) AND date('{{ env_var("exe_end_date") }}')
    AND order_business_channel_code = '{{ var("retention_mart")["business_channel"] }}'
    AND order_managed_group_id IN {{ var("retention_mart")["managed_group_id"] }}
    AND UPPER(product_type_code) IN {{ var("retention_mart")["product_type_code"] }}
    AND source_system IN {{ var("fm_products")["source_system"] }}
/* -- Script Name = 001_fm_products_data.sql :: END -- */
{%- endmacro -%}