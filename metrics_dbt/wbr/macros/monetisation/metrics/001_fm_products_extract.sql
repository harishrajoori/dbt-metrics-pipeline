{%- macro fm_products_extract() -%}
/* -- Script Name = 001_fm_products_extract.sql :: BEGIN -- */
select
    year_month_day
    , product_pl
    , region
    , count(distinct transaction_order_id) as transaction_order_id_count
    , sum(total_number_of_tickets) as total_number_of_tickets
    , sum(booking_fee_number_of_tickets) as booking_fee_number_of_tickets
    , sum(refund_fee_number_of_tickets) as refund_fee_number_of_tickets
    , sum(coj_fee_number_of_tickets) as coj_fee_number_of_tickets
    , sum(mcp_number_of_tickets) as mcp_number_of_tickets
    , sum(total_revenue_eur) as total_revenue_eur
    , sum(total_revenue_gbp) as total_revenue_gbp
    , sum(fee_revenue_eur) as fee_revenue_eur
    , sum(fee_revenue_gbp) as fee_revenue_gbp
    , sum(non_fee_revenue_eur) as non_fee_revenue_eur
    , sum(non_fee_revenue_gbp) as non_fee_revenue_gbp
    , sum(booking_fee_revenue_eur) as booking_fee_revenue_eur
    , sum(booking_fee_revenue_gbp) as booking_fee_revenue_gbp
    , sum(refund_fee_revenue_eur) as refund_fee_revenue_eur
    , sum(refund_fee_revenue_gbp) as refund_fee_revenue_gbp
    , sum(coj_fee_revenue_eur) as coj_fee_revenue_eur
    , sum(coj_fee_revenue_gbp) as coj_fee_revenue_gbp
    , sum(commission_revenue_eur) as commission_revenue_eur
    , sum(commission_revenue_gbp) as commission_revenue_gbp
    , sum(insurance_commission_revenue_eur) as insurance_commission_revenue_eur
    , sum(insurance_commission_revenue_gbp) as insurance_commission_revenue_gbp
    , sum(mcp_revenue_eur) as mcp_revenue_eur
    , sum(mcp_revenue_gbp) as mcp_revenue_gbp
    , sum(net_sales_amount_eur) as net_sales_amount_eur
    , sum(net_sales_amount_gbp) as net_sales_amount_gbp
from (

    SELECT
        date(year_month_day) AS year_month_day
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        , rm.output_product_pl as product_pl
        , rm.output_region as region
        /* ------------------------------------------------------------------------------------------------------- -- */
        , IF(product_gross_sales_flag = 'Y' AND record_type = 'SALES', order_id) AS transaction_order_id
        , product_number_of_tickets AS total_number_of_tickets
        , case when m_revenue_booking_fee_eur + m_revenue_booking_fee_gbp > 0 then product_number_of_tickets end as booking_fee_number_of_tickets
        , case when m_revenue_refund_admin_fee_eur + m_revenue_refund_admin_fee_gbp > 0 then product_number_of_tickets end as refund_fee_number_of_tickets
        , case when m_revenue_coj_admin_fee_eur + m_revenue_coj_admin_fee_gbp > 0 then product_number_of_tickets end as coj_fee_number_of_tickets
        , case when m_revenue_fx_margin_eur + m_revenue_fx_margin_gbp > 0 then product_number_of_tickets end as mcp_number_of_tickets
        , m_revenue_total_eur AS total_revenue_eur
        , m_revenue_total_gbp AS total_revenue_gbp
        , m_revenue_total_fees_eur AS fee_revenue_eur
        , m_revenue_total_fees_gbp AS fee_revenue_gbp
        , (m_revenue_total_eur - m_revenue_total_fees_eur) AS non_fee_revenue_eur
        , (m_revenue_total_gbp - m_revenue_total_fees_gbp) AS non_fee_revenue_gbp
        , m_revenue_booking_fee_eur AS booking_fee_revenue_eur
        , m_revenue_booking_fee_gbp AS booking_fee_revenue_gbp
        , m_revenue_refund_admin_fee_eur AS refund_fee_revenue_eur
        , m_revenue_refund_admin_fee_gbp AS refund_fee_revenue_gbp
        , m_revenue_coj_admin_fee_eur AS coj_fee_revenue_eur
        , m_revenue_coj_admin_fee_gbp AS coj_fee_revenue_gbp
        , m_revenue_product_commission_amount_eur AS commission_revenue_eur
        , m_revenue_product_commission_amount_gbp AS commission_revenue_gbp
        , m_revenue_insurance_commission_amount_eur AS insurance_commission_revenue_eur
        , m_revenue_insurance_commission_amount_gbp AS insurance_commission_revenue_gbp
        , m_revenue_fx_margin_eur AS mcp_revenue_eur
        , m_revenue_fx_margin_gbp AS mcp_revenue_gbp
        , m_net_sales_amount_eur AS net_sales_amount_eur
        , m_net_sales_amount_gbp AS net_sales_amount_gbp
    FROM
        {{ source("bi_dwh", "fm_products") }}
    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
    inner join 
        {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
        on (coalesce(product_pl_code,'(null)') = rm.input_product_pl and coalesce(order_region_name, '(null)') = rm.input_region)
    /* ------------------------------------------------------------------------------------------------------- -- */
    WHERE
        date(year_month_day) BETWEEN DATE_ADD('day', -45, date('{{ env_var("exe_start_date") }}')) AND date('{{ env_var("exe_end_date") }}')
        AND order_business_channel_code = '{{ var("monetisation_mart")["business_channel"] }}'
        AND order_managed_group_id IN {{ var("monetisation_mart")["managed_group_id"] }} -- include transactions made for both MyCompany as well as PartnerCompany
        AND UPPER(product_type_code) IN {{ var("monetisation_mart")["product_type_code"] }}
        AND source_system IN {{ var("fm_products")["source_system"] }}
)
group by year_month_day, product_pl, region
/* -- Script Name = 001_fm_products_extract.sql :: END -- */
{%- endmacro -%}