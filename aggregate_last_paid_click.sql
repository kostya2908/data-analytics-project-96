--STEP_2--
DROP VIEW paid_visits CASCADE;
CREATE VIEW paid_visits AS (
    SELECT DISTINCT ON (visitor_id)
        visitor_id,
        visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign
    FROM sessions
    WHERE medium != 'organic'
    ORDER BY 1, 2 DESC
);
CREATE VIEW step_2 AS (
    SELECT
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    FROM paid_visits
    LEFT JOIN leads
        ON
            paid_visits.visitor_id = leads.visitor_id
    WHERE visit_date <= created_at
    ORDER BY 8 DESC NULLS LAST, 2, 3-- LIMIT 10
);
--STEP_3--
DROP VIEW vk_date_spent CASCADE;
CREATE VIEW vk_date_spent AS (
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        DATE(campaign_date) AS day_vk,
        SUM(daily_spent) AS sum_vk
    FROM vk_ads
    GROUP BY 4, 1, 2, 3
    ORDER BY 4, 1, 2, 3
);

DROP VIEW ya_date_spent CASCADE;
CREATE VIEW ya_date_spent AS (
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        DATE(campaign_date) AS day_ya,
        SUM(daily_spent) AS sum_ya
    FROM ya_ads
    GROUP BY 4, 1, 2, 3
    ORDER BY 4, 1, 2, 3
);

SELECT
    DATE(pv.visit_date) AS visit_date,
    COUNT(pv.visitor_id) AS visitors_count,
    pv.utm_source,
    pv.utm_medium,
    pv.utm_campaign,
    CASE
        WHEN vds.sum_vk IS NULL THEN yds.sum_ya
        WHEN yds.sum_ya IS NULL THEN vds.sum_vk
    END AS total_cost,
    COUNT(s2.lead_id) AS leads_count,
    COUNT(s2.lead_id) FILTER (WHERE status_id = 142) AS purchases_count,
    SUM(amount) AS revenue
FROM paid_visits AS pv
LEFT JOIN vk_date_spent AS vds
    ON
        vds.day_vk = DATE(pv.visit_date)
        AND vds.utm_source = pv.utm_source
        AND vds.utm_medium = pv.utm_medium
        AND vds.utm_campaign = pv.utm_campaign
LEFT JOIN ya_date_spent AS yds
    ON
        yds.day_ya = DATE(pv.visit_date)
        AND yds.utm_source = pv.utm_source
        AND yds.utm_medium = pv.utm_medium
        AND yds.utm_campaign = pv.utm_campaign
LEFT JOIN step_2 AS s2
    ON
        pv.visitor_id = s2.visitor_id
GROUP BY 1, 3, 4, 5, 6
ORDER BY 9 DESC NULLS LAST, 1, 2, 3, 4, 5 LIMIT 15;