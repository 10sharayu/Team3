-- TICKET-ADV010: VWAP per instrument per day

SELECT
    trade_id,
    instrument_id,
    trade_date,
    quantity,
    price,
    quantity * price AS notional,

    SUM(price * quantity)
        OVER (
            PARTITION BY instrument_id, trade_date
        )
    /
    NULLIF(
        SUM(quantity)
            OVER (
                PARTITION BY instrument_id, trade_date
            ),
        0
    ) AS vwap

FROM trades

ORDER BY
    instrument_id,
    trade_date,
    trade_id;




-- ============================================================================
-- Recursive CTE: trade lifecycle (execution -> settlement
--                -> recon_break -> resolution)
-- ============================================================================
WITH RECURSIVE trade_lifecycle AS (
    -- anchor: every trade in its execution state
    SELECT
        t.id           AS trade_id,
        t.trade_ref,
        1              AS step,
        'EXECUTED'     AS state,
        t.created_at   AS at_ts,
        NULL::text     AS detail
    FROM trades t
    WHERE t.deleted_at IS NULL

    UNION ALL

    -- recursive: each subsequent state derived from the previous step
    SELECT
        tl.trade_id,
        tl.trade_ref,
        tl.step + 1,
        CASE tl.step
            WHEN 1 THEN 'CONFIRMED'
            WHEN 2 THEN 'SETTLED'
            WHEN 3 THEN 'RECONCILED'
        END                                          AS state,
        s.settlement_date::timestamp                  AS at_ts,
        s.status                                      AS detail
    FROM trade_lifecycle tl
    JOIN settlements s ON s.trade_id = tl.trade_id
    WHERE tl.step < 4
)
SELECT * FROM trade_lifecycle
ORDER BY trade_id, step;