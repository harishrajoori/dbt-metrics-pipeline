{%- macro anaplan_day() -%}
/* -- Script Name = anaplan_day.sql :: BEGIN -- */
WITH
/* ---
    Below CTE provides day of week ratio for all 7 days in a week
    based on net sales in last 6 months
    --- */
    ratio as
    (
        select day_of_reporting_week
              ,avg_dow / avg_daily as ratio
        from (
                select day_of_reporting_week
                       ,avg_dow
                       ,sum(avg_dow) over () avg_week_total
                       ,sum(avg_dow) over () / 7 avg_daily
                from (
                         select day_of_reporting_week
                               ,avg(sum_net_daily) avg_dow
                           from (
                                 select se.start_date
                                       ,se.end_date
                                       ,c.report_week_commencing
                                       ,c.day_of_reporting_week
                                       ,sum(f.m_net_sales_amount_gbp) sum_net_daily
                                 from {{ source("bi_dwh", "fm_products") }} f
                                 join ( select cast(date(min(report_week_commencing)) as varchar) start_date
                                              ,cast(date(max(report_week_ending)) as varchar) end_date
                                          from {{ source("bi_dwh_ref_data", "bi_d_calendar") }}
                                         where date(report_date) in (date_add('month', -6, current_date)
                                                                     ,current_date)) se
                                    on  f.year_month_day between se.start_date and se.end_date
                                 join {{ source("bi_dwh_ref_data", "bi_d_calendar") }} c
                                   on f.year_month_day = cast(date(c.report_date) as varchar)
                                 group by 1,2,3,4
                                 )
                         group by 1
                      )
              )
    ),

    /* ---
        Below CTE provides the total number of days in a month
        --- */
    days_in_month as
     (
        select
            date_format(report_date, '%Y-%m') as year_month
            ,date(report_date) as report_date
            ,day_of_reporting_week
            ,week_in_fin_year
            ,report_week_commencing
            ,max(day_of_month) over(partition by date_format(report_date, '%Y-%m')) as days_month
        from {{ source("bi_dwh_ref_data", "bi_d_calendar") }}
     )

select
    'DAY' AS date_scope
    ,ab.version
    ,dm.report_date as year_month_day
    ,dm.week_in_fin_year
    ,date(dm.report_week_commencing) as week_commencing_date
    ,CASE
        WHEN ab.region = 'ROE' THEN 'RoE'
        WHEN ab.region = 'ROW' THEN 'Inbound'
        WHEN ab.region = 'Unknown' THEN 'France'
        ELSE ab.region
    END AS region
    ,CAST(current_time AS timestamp) AS last_modified
    ,cast((gross_sales_budget * ratio) / days_month as decimal(38,2)) as gross_sales_budget
    ,cast((net_sales_budget * ratio)/ days_month as decimal(38,2)) as net_sales_budget
    ,cast((new_customers_budget * ratio)/ days_month as decimal(38,2)) as new_customers_budget
    ,cast((gross_transactions_budget * ratio)/ days_month as decimal(38,2)) as gross_transactions_budget
    ,IF(gross_transactions_budget > 0, ((gross_sales_budget*1.00)/(gross_transactions_budget*1.00)), 0) as average_transaction_value_budget
    ,cast((performance_marketing_spend_budget * ratio)/ days_month as decimal(38,2)) as marketing_spend_budget
    ,cast((total_revenue_budget * ratio)/ days_month as decimal(38,2)) as total_revenue_budget
    ,cast((total_costs_budget * ratio)/ days_month as decimal(38,2)) as total_costs_budget
    ,cast(((total_revenue_budget + total_costs_budget) * ratio)/ days_month as decimal(38,2)) as gross_margin_budget
    ,cast(((total_revenue_budget + total_costs_budget - performance_marketing_spend_budget) * ratio)/ days_month as decimal(38,2)) as gm_minus_pms_budget
--    ,cast((net_sales_gbp * ratio)/ days_month as decimal(38,2)) as net_sales_gbp
--    ,cast((net_transactions * ratio)/ days_month as decimal(38,2)) as net_transactions
--    ,cast((advertising_revenue * ratio)/ days_month as decimal(38,2)) as advertising_revenue
--    ,cast((ancillary_revenue * ratio)/ days_month as decimal(38,2)) as ancillary_revenue
--    ,cast((api_revenue * ratio)/ days_month as decimal(38,2)) as api_revenue
--    ,cast((bespoke_revenue * ratio)/ days_month as decimal(38,2)) as bespoke_revenue
--    ,cast((booking_fee * ratio)/ days_month as decimal(38,2)) as booking_fee
--    ,cast((commission * ratio)/ days_month as decimal(38,2)) as commission
--    ,cast((commission_passback * ratio)/ days_month as decimal(38,2)) as commission_passback
--    ,cast((crm_revenue * ratio)/ days_month as decimal(38,2)) as crm_revenue
--    ,cast((delay_repay_revenue * ratio)/ days_month as decimal(38,2)) as delay_repay_revenue
--    ,cast((fulfilment_fee * ratio)/ days_month as decimal(38,2)) as fulfilment_fee
--    ,cast((hotels_revenue * ratio)/ days_month as decimal(38,2)) as hotels_revenue
--    ,cast((insurance_revenue * ratio)/ days_month as decimal(38,2)) as insurance_revenue
--    ,cast((multi_currency_platform * ratio)/ days_month as decimal(38,2)) as multi_currency_platform
--    ,cast((other_revenue * ratio)/ days_month as decimal(38,2)) as other_revenue
--    ,cast((other_ticket_revenue * ratio)/ days_month as decimal(38,2)) as other_ticket_revenue
--    ,cast((printers * ratio)/ days_month as decimal(38,2)) as printers
--    ,cast((profit_and_loss * ratio)/ days_month as decimal(38,2)) as profit_and_loss
--    ,cast((punch_out_revenue * ratio)/ days_month as decimal(38,2)) as punch_out_revenue
--    ,cast((rail_revenue * ratio)/ days_month as decimal(38,2)) as rail_revenue
--    ,cast((refund_fee * ratio)/ days_month as decimal(38,2)) as refund_fee
--    ,cast((settlement_fee * ratio)/ days_month as decimal(38,2)) as settlement_fee
--    ,cast((support_fee * ratio)/ days_month as decimal(38,2)) as support_fee
--    ,cast((web_loyalty * ratio)/ days_month as decimal(38,2)) as web_loyalty
--    ,cast((advertising_cost_of_sales * ratio)/ days_month as decimal(38,2)) as advertising_cost_of_sales
--    ,cast((ancillary_cost_of_sales * ratio)/ days_month as decimal(38,2)) as ancillary_cost_of_sales
--    ,cast((bespoke_cost_of_sales * ratio)/ days_month as decimal(38,2)) as bespoke_cost_of_sales
--    ,cast((customer_service_cost_of_sales * ratio)/ days_month as decimal(38,2)) as customer_service_cost_of_sales
--    ,cast((fulfilment_cost_of_sales * ratio)/ days_month as decimal(38,2)) as fulfilment_cost_of_sales
--    ,cast((headwind_risk_adjustment * ratio)/ days_month as decimal(38,2)) as headwind_risk_adjustment
--    ,cast((industry_costs * ratio)/ days_month as decimal(38,2)) as industry_costs
--    ,cast((insurance_cost_of_sales * ratio)/ days_month as decimal(38,2)) as insurance_cost_of_sales
--    ,cast((multi_currency_platform_cost_of_sales * ratio)/ days_month as decimal(38,2)) as multi_currency_platform_cost_of_sales
--    ,cast((pao_cost_of_sales * ratio)/ days_month as decimal(38,2)) as pao_cost_of_sales
--    ,cast((printers_cost_of_sales * ratio)/ days_month as decimal(38,2)) as printers_cost_of_sales
--    ,cast((promo_codes * ratio)/ days_month as decimal(38,2)) as promo_codes
--    ,cast((rail_cost_of_sales * ratio)/ days_month as decimal(38,2)) as rail_cost_of_sales
--    ,cast((risk_adjustment_cost_of_sales * ratio)/ days_month as decimal(38,2)) as risk_adjustment_cost_of_sales
--    ,cast((settlement_cost_of_sales * ratio)/ days_month as decimal(38,2)) as settlement_cost_of_sales
--    ,cast((rebates * ratio)/ days_month as decimal(38,2)) as rebates
--    ,cast((admin_costs * ratio)/ days_month as decimal(38,2)) as admin_costs
--    ,cast((aws_admin_costs * ratio)/ days_month as decimal(38,2)) as aws_admin_costs
--    ,cast((cloud_admin_costs * ratio)/ days_month as decimal(38,2)) as cloud_admin_costs
--    ,cast((comms_admin_costs * ratio)/ days_month as decimal(38,2)) as comms_admin_costs
--    ,cast((corporate_affairs_admin_costs * ratio)/ days_month as decimal(38,2)) as corporate_affairs_admin_costs
--    ,cast((delay_repay_admin_costs * ratio)/ days_month as decimal(38,2)) as delay_repay_admin_costs
--    ,cast((direct_admin_costs * ratio)/ days_month as decimal(38,2)) as direct_admin_costs
--    ,cast((facilities_admin_costs * ratio)/ days_month as decimal(38,2)) as facilities_admin_costs
--    ,cast((finance_related_admin_costs * ratio)/ days_month as decimal(38,2)) as finance_related_admin_costs
--    ,cast((headcount_admin_costs * ratio)/ days_month as decimal(38,2)) as headcount_admin_costs
--    ,cast((hr_related_staff_admin_costs * ratio)/ days_month as decimal(38,2)) as hr_related_staff_admin_costs
--    ,cast((it_communication_admin_costs * ratio)/ days_month as decimal(38,2)) as it_communication_admin_costs
--    ,cast((journey_planning_admin_costs * ratio)/ days_month as decimal(38,2)) as journey_planning_admin_costs
--    ,cast((legal_professional_admin_costs * ratio)/ days_month as decimal(38,2)) as legal_professional_admin_costs
--    ,cast((mobile_admin_costs * ratio)/ days_month as decimal(38,2)) as mobile_admin_costs
--    ,cast((ops_losses_admin_costs * ratio)/ days_month as decimal(38,2)) as ops_losses_admin_costs
--    ,cast((other_admin_costs * ratio)/ days_month as decimal(38,2)) as other_admin_costs
--    ,cast((profit_loss_admin_costs * ratio)/ days_month as decimal(38,2)) as profit_loss_admin_costs
--    ,cast((recruitment_admin_costs * ratio)/ days_month as decimal(38,2)) as recruitment_admin_costs
--    ,cast((security_admin_costs * ratio)/ days_month as decimal(38,2)) as security_admin_costs
--    ,cast((servicing_tooling_admin_costs * ratio)/ days_month as decimal(38,2)) as servicing_tooling_admin_costs
--    ,cast((software_licences_admin_costs * ratio)/ days_month as decimal(38,2)) as software_licences_admin_costs
--    ,cast((staff_payroll_admin_costs * ratio)/ days_month as decimal(38,2)) as staff_payroll_admin_costs
--    ,cast((staff_related_overheads_admin_costs * ratio)/ days_month as decimal(38,2)) as staff_related_overheads_admin_costs
--    ,cast((sustainability_admin_costs * ratio)/ days_month as decimal(38,2)) as sustainability_admin_costs
--    ,cast((system_admin_costs * ratio)/ days_month as decimal(38,2)) as system_admin_costs
--    ,cast((temporary_contractor_admin_costs * ratio)/ days_month as decimal(38,2)) as temporary_contractor_admin_costs
--    ,cast((total_business_admin_costs * ratio)/ days_month as decimal(38,2)) as total_business_admin_costs
--    ,cast((travel_entertainment_admin_costs * ratio)/ days_month as decimal(38,2)) as travel_entertainment_admin_costs
--    ,cast((direct_costs * ratio)/ days_month as decimal(38,2)) as direct_costs
--    ,cast((total_business_marketing_value * ratio)/ days_month as decimal(38,2)) as total_business_marketing_value
--    ,cast((profit_and_loss_marketing_value * ratio)/ days_month as decimal(38,2)) as profit_and_loss_marketing_value
--    ,cast((marketing_value * ratio)/ days_month as decimal(38,2)) as marketing_value
--    ,cast((brand_marketing_value * ratio)/ days_month as decimal(38,2)) as brand_marketing_value
--    ,cast((performance_marketing_value * ratio)/ days_month as decimal(38,2)) as performance_marketing_value
--    ,cast((other_marketing_marketing_value * ratio)/ days_month as decimal(38,2)) as other_marketing_marketing_value
--    ,cast((brand_value * ratio)/ days_month as decimal(38,2)) as brand_value
--    ,cast((ppc_marketing_value * ratio)/ days_month as decimal(38,2)) as ppc_marketing_value
--    ,cast((display_marketing_value * ratio)/ days_month as decimal(38,2)) as display_marketing_value
--    ,cast((seo_marketing_value * ratio)/ days_month as decimal(38,2)) as seo_marketing_value
--    ,cast((affiliates_marketing_value * ratio)/ days_month as decimal(38,2)) as affiliates_marketing_value
--    ,cast((paid_social_marketing_value * ratio)/ days_month as decimal(38,2)) as paid_social_marketing_value
--    ,cast((crm_marketing_value * ratio)/ days_month as decimal(38,2)) as crm_marketing_value
--    ,cast((research_marketing_value * ratio)/ days_month as decimal(38,2)) as research_marketing_value
--    ,cast((other_marketing_value * ratio)/ days_month as decimal(38,2)) as other_marketing_value
--    ,cast((b2b_marketing_value * ratio)/ days_month as decimal(38,2)) as b2b_marketing_value
--    ,cast((contingency_marketing_value * ratio)/ days_month as decimal(38,2)) as contingency_marketing_value
--    ,cast((direct_marketing_value * ratio)/ days_month as decimal(38,2)) as direct_marketing_value
--    ,cast((intl_marketing_spend * ratio)/ days_month as decimal(38,2)) as intl_marketing_spend
--    ,cast((total_business_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as total_business_marketing_spend_intl
--    ,cast((profit_and_loss_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as profit_and_loss_marketing_spend_intl
--    ,cast((marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as marketing_spend_intl
--    ,cast((brand_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as brand_marketing_spend_intl
--    ,cast((performace_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as performace_marketing_spend_intl
--    ,cast((other_marketing_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as other_marketing_marketing_spend_intl
--    ,cast((brand_spend_intl * ratio)/ days_month as decimal(38,2)) as brand_spend_intl
--    ,cast((ppc_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as ppc_marketing_spend_intl
--    ,cast((display_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as display_marketing_spend_intl
--    ,cast((seo_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as seo_marketing_spend_intl
--    ,cast((affiliates_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as affiliates_marketing_spend_intl
--    ,cast((paid_social_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as paid_social_marketing_spend_intl
--    ,cast((crm_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as crm_marketing_spend_intl
--    ,cast((research_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as research_marketing_spend_intl
--    ,cast((other_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as other_marketing_spend_intl
--    ,cast((b2b_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as b2b_marketing_spend_intl
--    ,cast((contingency_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as contingency_marketing_spend_intl
--    ,cast((direct_marketing_spend_intl * ratio)/ days_month as decimal(38,2)) as direct_marketing_spend_intl
from {{ source("bi_dwh_finance", "v_anaplan_budget_data") }} ab
left join days_in_month dm
    on dm.year_month =  ab.year_month
left join ratio r
    on dm.day_of_reporting_week = r.day_of_reporting_week
where ab.region in ('France', 'Germany', 'ROW', 'Italy', 'ROE', 'Spain', 'UK>EU', 'United Kingdom')
/* -- Script Name = anaplan_day.sql :: END -- */
{%- endmacro -%}
