--STEP_2--
DROP VIEW paid_visits CASCADE;
CREATE VIEW paid_visits AS (
    SELECT DISTINCT ON (visitor_id)
        visitor_id,
        visit_date
    FROM sessions
    WHERE medium != 'organic'
    ORDER BY 1, 2 DESC
);
CREATE VIEW step_2 AS (
    SELECT
        pv.visitor_id,
        pv.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM paid_visits AS pv
    LEFT JOIN sessions AS s
        ON
            pv.visitor_id = s.visitor_id
            AND pv.visit_date = s.visit_date
    LEFT JOIN leads AS l
        ON
            pv.visitor_id = l.visitor_id
    WHERE pv.visit_date <= l.created_at
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
    s2.utm_source,
    s2.utm_medium,
    s2.utm_campaign,
    DATE(pv.visit_date) AS visit_date,
    COUNT(pv.visitor_id) AS visitors_count,
    CASE
        WHEN vds.sum_vk IS NULL THEN yds.sum_ya
        WHEN yds.sum_ya IS NULL THEN vds.sum_vk
    END AS total_cost,
    COUNT(s2.lead_id) AS leads_count,
    COUNT(s2.lead_id) FILTER (WHERE s2.status_id = 142) AS purchases_count,
    SUM(s2.amount) AS revenue
FROM paid_visits AS pv
LEFT JOIN step_2 AS s2
    ON
        pv.visitor_id = s2.visitor_id
LEFT JOIN vk_date_spent AS vds
    ON
        vds.day_vk = DATE(pv.visit_date)
        AND vds.utm_source = s2.utm_source
        AND vds.utm_medium = s2.utm_medium
        AND vds.utm_campaign = s2.utm_campaign
LEFT JOIN ya_date_spent AS yds
    ON
        yds.day_ya = DATE(pv.visit_date)
        AND yds.utm_source = s2.utm_source
        AND yds.utm_medium = s2.utm_medium
        AND yds.utm_campaign = s2.utm_campaign
GROUP BY 4, 1, 2, 3, 6
ORDER BY 9 DESC NULLS LAST, 3, 4, 1, 2, 3 LIMIT 15;
