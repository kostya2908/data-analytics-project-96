WITH tab AS (
    SELECT DISTINCT ON (visitor_id)
        visitor_id,
        visit_date
    FROM sessions
    WHERE medium != 'organic'
    ORDER BY 1, 2 DESC
)

SELECT
    tab.visitor_id,
    tab.visit_date,
    s.source AS utm_source,
    s.medium AS utm_medium,
    s.campaign AS utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
FROM tab
LEFT JOIN sessions AS s
    ON
        tab.visitor_id = s.visitor_id
        AND tab.visit_date = s.visit_date
LEFT JOIN leads AS l
    ON
        tab.visitor_id = l.visitor_id
WHERE tab.visit_date <= l.created_at
ORDER BY 8 DESC NULLS LAST, 2, 3 LIMIT 10;
