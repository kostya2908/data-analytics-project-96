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

--DROP VIEW step_3 CASCADE;
CREATE VIEW step_3 AS (
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
    GROUP BY 1, 2, 3, 4, 6
    ORDER BY 9 DESC NULLS LAST, 3, 4, 1, 2, 3-- LIMIT 15;
);

--STEP_4--querries_for_dashboard--
--1.1. Общее количество посетителей (всего):
SELECT
    CASE
        WHEN source = 'vk' THEN source
        WHEN source = 'yandex' THEN source
        WHEN source = 'google' THEN source
        ELSE 'other sources'
    END AS source,
    COUNT(visitor_id) AS visitors_count
FROM sessions
--Excluding 'organic' visitors:
--WHERE medium != 'organic'
GROUP BY 1;

--1.2. Посетители, привлеченные рекламой:
CREATE VIEW gr_1_2 AS (
    SELECT
        CASE
            WHEN utm_source = 'vk' THEN 'vk'
            WHEN utm_source = 'yandex' THEN 'yandex'
            ELSE 'other_adv_campaign'
        END AS source,
        SUM(visitors_count) AS vis_count, -- этот столбец в графике 1.2.
        SUM(leads_count) AS sum_leads,
        SUM(purchases_count) AS sum_purch
    FROM step_3
    GROUP BY 1
);

--1.3. Посетители (все подряд), привлеченные рекламой по неделям:
SELECT
    TO_CHAR(visit_date, 'IYYY-IW') AS week_no,
    COUNT(visitor_id) AS visitors_count,
    CASE
        WHEN source = 'vk' THEN 'vk'
        WHEN source = 'yandex' THEN 'yandex'
        ELSE 'other_adv_campaign'
    END AS smc
FROM sessions
WHERE medium != 'organic'
GROUP BY 1, 3
ORDER BY 1, 2 DESC;

--1.4. Количество посетителей по дням:
SELECT
    DATE(visit_date) AS visit_date,
    COUNT(visitor_id) AS visitors_count,
    CASE
        WHEN source = 'vk' THEN 'vk'
        WHEN source = 'yandex' THEN 'yandex'
        ELSE 'other_adv_campaign'
    END AS smc
FROM sessions
WHERE medium != 'organic'
GROUP BY 1, 3
ORDER BY 1, 2 DESC;

--1.5. Рост количества посетителей в течение месяца:
--DROP VIEW visits_by_source;
CREATE VIEW visits_by_source AS (
    SELECT
        DATE(visit_date) AS visit_date,
        COUNT(visitor_id) FILTER (WHERE source = 'vk') AS vk_visits,
        COUNT(visitor_id) FILTER (WHERE source = 'yandex') AS ya_visits,
        COUNT(visitor_id) FILTER (WHERE source = 'google') AS google_visits,
        COUNT(visitor_id)
        FILTER
        (WHERE source != 'vk' AND source != 'yandex' AND source != 'google')
        AS other_visits,
        COUNT(visitor_id) FILTER (WHERE medium = 'organic') AS organic_visits
    FROM sessions
    GROUP BY 1
    ORDER BY 1
);
SELECT
    visit_date,
    SUM(vk_visits) OVER (ORDER BY visit_date) AS total_vk,
    SUM(ya_visits) OVER (ORDER BY visit_date) AS total_ya,
    SUM(google_visits) OVER (ORDER BY visit_date) AS total_google,
    SUM(other_visits) OVER (ORDER BY visit_date) AS total_other,
    SUM(organic_visits) OVER (ORDER BY visit_date) AS total_organic
FROM visits_by_source;

--2.1 Распределение лидов, их источники:
--DROP VIEW gr_2_1;
CREATE VIEW gr_2_1 AS (
    SELECT
        CASE
            WHEN utm_source = 'vk' THEN 'vk'
            WHEN utm_source = 'yandex' THEN 'yandex'
            ELSE 'other_adv_campaign'
        END AS source,
        SUM(leads_count) AS sum_leads
    FROM step_3
    GROUP BY 1
);

--2.2. Распределение покупателей, их источники:
CREATE VIEW gr_2_2 AS (
    SELECT
        CASE
            WHEN utm_source = 'vk' THEN 'vk'
            WHEN utm_source = 'yandex' THEN 'yandex'
            ELSE 'other_adv_campaign'
        END AS source,
        SUM(purchases_count) AS sum_purch
    FROM step_3
    GROUP BY 1
);

--3.1. Рост затрат на рекламу в течение месяца:
WITH tab_vk AS (
    SELECT
        DATE(campaign_date) AS date_vk,
        SUM(daily_spent) AS sum_daily_vk
    FROM vk_ads
    GROUP BY 1
    ORDER BY 1
),

tab_ya AS (
    SELECT
        DATE(campaign_date) AS date_ya,
        SUM(daily_spent) AS sum_daily_ya
    FROM ya_ads
    GROUP BY 1
    ORDER BY 1
)

SELECT
    tv.date_vk AS date_,
    SUM(tv.sum_daily_vk) OVER (ORDER BY tv.date_vk) AS spent_vk,
    SUM(ty.sum_daily_ya) OVER (ORDER BY ty.date_ya) AS spent_ya
FROM tab_vk AS tv
LEFT JOIN
    tab_ya AS ty
    ON tv.date_vk = ty.date_ya;

--3.2. Затраты на рекламу VK по UTM_Medium,
--3.3. Затраты на рекламу VK по UTM_Campaign:
SELECT
    utm_medium,
    campaign_name,
    SUM(daily_spent) AS spent_on
FROM vk_ads
GROUP BY 1, 2
ORDER BY 1, 2;

--3.4. Затраты на рекламу Yandex по UTM_Medium
--3.5. Затраты на рекламу Yandex по UTM_Campaign:
SELECT
    utm_medium,
    campaign_name,
    SUM(daily_spent) AS spent_on
FROM ya_ads
GROUP BY 1, 2
ORDER BY 1, 2;

--3.6. Затраты на рекламные кампании VK, Yandex:
DROP VIEW gr_3_6;
CREATE VIEW gr_3_6 AS (
    (SELECT
        utm_source,
        SUM(daily_spent) AS sum_daily_spent
    FROM vk_ads GROUP BY 1)
    UNION ALL
    (SELECT
        utm_source,
        SUM(daily_spent) AS sum_daily_spent
    FROM ya_ads GROUP BY 1)
);

--3.7. Выручка от рекламных кампаний:
CREATE VIEW gr_3_7 AS (
    SELECT
        CASE
            WHEN utm_source = 'vk' THEN 'vk'
            WHEN utm_source = 'yandex' THEN 'yandex'
            ELSE 'other_adv_campaign'
        END AS source,
        SUM(revenue) AS profit
    FROM step_3
    GROUP BY 1
);

--
--4.1. PIVOT_TABLE--
DROP TABLE gr_4_1;
CREATE TABLE gr_4_1 (parameter VARCHAR, value FLOAT);

INSERT INTO gr_4_1 VALUES
('Количество всех посетителей:', (SELECT COUNT(visitor_id) FROM sessions)),
(
    'Количество посетителей, привлеченных рекламой:',
    (SELECT SUM(vis_count) FROM gr_1_2)
),
('Количество лидов:', (SELECT SUM(sum_leads) FROM gr_2_1)),
('Количество покупателей:', (SELECT SUM(sum_purch) FROM gr_2_2)),
(
    'Конверсия пользователь / лид (общая), %:',
    ROUND(
        100 * (SELECT SUM(sum_leads) FROM gr_2_1)
        / (SELECT SUM(vis_count) FROM gr_1_2), 2
    )
),
(
    'Конверсия лид / покупатель (общая), %:',
    ROUND(
        100 * (SELECT SUM(sum_purch) FROM gr_2_2)
        / (SELECT SUM(sum_leads) FROM gr_2_1), 2
    )
),
('Затраты на рекламу, руб.:', (SELECT SUM(sum_daily_spent) FROM gr_3_6)),
(
    ' - затраты на VK, руб.:',
    (SELECT SUM(sum_daily_spent) FROM gr_3_6 WHERE utm_source = 'vk')
),
(
    ' - затраты на Ya, руб.:',
    (SELECT SUM(sum_daily_spent) FROM gr_3_6 WHERE utm_source = 'yandex')
),
('Выручка, руб.:', (SELECT SUM(profit) FROM gr_3_7)),
(
    ' - выручка от VK, руб.:',
    (SELECT SUM(profit) FROM gr_3_7 WHERE source = 'vk')
),
(
    ' - выручка от Ya, руб.:',
    (SELECT SUM(profit) FROM gr_3_7 WHERE source = 'yandex')
),
(
    'cpu = total_cost / visitors_count, руб.:',
    ROUND(
        (SELECT SUM(sum_daily_spent) FROM gr_3_6)
        / (SELECT SUM(vis_count) FROM gr_1_2), 0
    )
),
(
    'cpl = total_cost / leads_count, руб.:',
    ROUND(
        (SELECT SUM(sum_daily_spent) FROM gr_3_6)
        / (SELECT SUM(sum_leads) FROM gr_2_1), 0
    )
),
(
    'cppu = total_cost / purchases_count, руб.:',
    ROUND(
        (SELECT SUM(sum_daily_spent) FROM gr_3_6)
        / (SELECT SUM(sum_purch) FROM gr_2_2), 0
    )
),
(
    'roi = (revenue - total_cost) / total_cost, %:',
    ROUND(
        100 * (
            (SELECT SUM(profit) FROM gr_3_7)
            - (SELECT SUM(sum_daily_spent) FROM gr_3_6)
        )
        / (SELECT SUM(sum_daily_spent) FROM gr_3_6), 2
    )
),
(
    ' - roi для VK, %:',
    ROUND(
        100 * (
            (SELECT SUM(profit) FROM gr_3_7 WHERE source = 'vk')
            - (SELECT SUM(sum_daily_spent) FROM gr_3_6 WHERE utm_source = 'vk')
        )
        / (SELECT SUM(sum_daily_spent) FROM gr_3_6 WHERE utm_source = 'vk'), 2
    )
),
(
    ' - roi для Ya, %:',
    ROUND(
        100 * (
            (SELECT SUM(profit) FROM gr_3_7 WHERE source = 'yandex')
            - (
                SELECT SUM(sum_daily_spent) FROM gr_3_6
                WHERE utm_source = 'yandex'
            )
        )
        / (
            SELECT SUM(sum_daily_spent) FROM gr_3_6
            WHERE utm_source = 'yandex'
        ), 2
    )
);

SELECT
    parameter,
    value
FROM gr_4_1;

--4.2. Best ROI by campaign:
SELECT
    CONCAT(utm_source, '/', utm_medium, '/', utm_campaign)
    AS utm_source__utm_medium__utm_campaign,
    SUM(total_cost) AS total_cost,
    SUM(revenue) AS revenue,
    ROUND(SUM(total_cost) / SUM(visitors_count), 2) AS cpu,
    ROUND(SUM(total_cost) / SUM(leads_count), 2) AS cpl,
    ROUND(SUM(total_cost) / SUM(purchases_count), 2) AS cppu,
    ROUND(
        100 * (SUM(revenue) - SUM(total_cost)) / SUM(total_cost)
        FILTER (WHERE total_cost > 0), 2
    ) AS roi
FROM step_3
WHERE revenue > 0 AND total_cost IS NOT NULL
GROUP BY 1
ORDER BY 7 DESC NULLS LAST;

--4.3. Visitors correlation - ADV - Organic
-- см. п. 1.5.

--4.4. время от перехода по ссылке до покупки:
DROP VIEW gr_4_4;
CREATE VIEW gr_4_4 AS (
    SELECT
        AGE(DATE(created_at), DATE(visit_date)) AS purchaser_age,
        COUNT(AGE(DATE(created_at), DATE(visit_date))) AS age_count
    FROM step_2
    WHERE status_id = 142
    GROUP BY 1
    ORDER BY 1
);
SELECT
    purchaser_age AS lead_buyer_period,
    age_count AS orders_quantity,
    SUM(age_count) OVER (ORDER BY purchaser_age) AS sum_orders_quantity
FROM gr_4_4
ORDER BY 1;
