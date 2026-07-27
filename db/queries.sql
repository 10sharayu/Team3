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