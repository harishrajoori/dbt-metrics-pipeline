{% test validate_foreign_travel_acquisition(model) %}
/* -- 
    this dq test validates the aggregated metric value for foreign travel region
    against that of the summation of the metric values from the base regions (inbound, roe, uk>eu)
    for additive metrics (metrics not derived as the quotient of two other metrics)
-- */
WITH 
	base_regions AS 
	(
		SELECT 
			date_scope,
			year_month_day,
			category,
			sub_category,
			metric_name,
			SUM(metric_value) AS metric_value
		FROM 
			{{ model }}
		WHERE 
			(
				product_pl  = 'EU'
				AND 
				region IN ('Inbound', 'RoE', 'UK>EU')
			)
		AND 
			metric_name NOT IN ('Active Customers', 'Existing Customers', 'New Customers', 'Incremental ROAS')
		GROUP BY 
			1,2,3,4,5
	),
	foreign_travel AS 
	(
		SELECT 
			date_scope,
			year_month_day,
			category,
			sub_category,
			metric_name,
			metric_value
		FROM 
			{{ model }}
		WHERE 
			(
				product_pl  = 'EU'
				AND 
				region IN ('Foreign Travel')
			)
		AND 
			metric_name NOT IN ('Active Customers', 'Existing Customers', 'New Customers', 'Incremental ROAS')
	),
	data_compare AS 
	(
		SELECT 
			br.date_scope,
			br.year_month_day,
			br.metric_name,
			br.category,
			br.sub_category,
			br.metric_value AS base_regions_metric_values_summation,
			ft.metric_value AS foreign_travel_metric_value,
			ABS(br.metric_value-ft.metric_value) AS abs_difference
		FROM 
			base_regions br 
			FULL OUTER JOIN foreign_travel ft 
			ON 
			(
				br.date_scope=ft.date_scope
				AND 
				br.year_month_day=ft.year_month_day
				AND 
				br.category=ft.category
				AND 
				br.sub_category=ft.sub_category
				AND 
				br.metric_name=ft.metric_name
			)
	)
SELECT 
	*
FROM 
	data_compare
WHERE 
	abs_difference > 10
ORDER BY 
	1,2,3,4,5
{% endtest %}