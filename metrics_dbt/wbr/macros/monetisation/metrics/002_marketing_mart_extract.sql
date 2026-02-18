{%- macro marketing_mart_extract() -%}
/* -- Script Name = 002_marketing_mart_extract.sql :: BEGIN -- */
SELECT
    date(activity_date) AS year_month_day,
	/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
	rm.output_product_pl as product_pl,
	rm.output_region as region,
	/* ------------------------------------------------------------------------------------------------------- -- */
    value AS total_visits
FROM {{ source("bi_dwh", "marketing_mart") }}
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
inner join 
    {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
    on (coalesce(pnl_segment,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
/* ------------------------------------------------------------------------------------------------------- -- */
WHERE
    date(activity_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
    AND kpi = 'Visits'
/* -- Script Name = 002_marketing_mart_extract.sql :: END -- */
{%- endmacro -%}