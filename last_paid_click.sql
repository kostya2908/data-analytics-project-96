WITH tab AS (
	SELECT DISTINCT ON (visitor_id)
		visitor_id,
		DENSE_RANK() OVER (ORDER BY visitor_id),
		visit_date,
		source,
		medium,
		campaign
	FROM sessions
	WHERE medium != 'organic'
	ORDER BY 1,3 DESC
)
SELECT
	visitor_id,
	visit_date,
	source AS utm_source,
	medium AS utm_medium,
	campaign AS utm_campaign,
	lead_id,
	created_at,
	amount,
	closing_reason,
	status_id		
FROM tab
LEFT JOIN leads USING (visitor_id)
WHERE visit_date <= created_at
ORDER BY 8 DESC NULLS LAST, 2, 3 LIMIT 10;