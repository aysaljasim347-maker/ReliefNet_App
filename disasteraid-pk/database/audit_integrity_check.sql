-- Financial Integrity Check: Ledger vs Wallet Balances
-- This query identifies any discrepancies between the sum of ledger transactions and the actual stored balances.

WITH ledger_summary AS (
    SELECT 
        COALESCE(destination_id, source_id) as ngo_id,
        SUM(CASE WHEN transaction_type = 'DONATION' THEN amount ELSE 0 END) as calculated_received,
        SUM(CASE WHEN transaction_type = 'WITHDRAWAL' THEN amount ELSE 0 END) as calculated_withdrawn
    FROM public.wallet_transactions
    WHERE status = 'COMPLETED'
    GROUP BY COALESCE(destination_id, source_id)
)
SELECT 
    n.org_name,
    w.balance as stored_balance,
    (ls.calculated_received - ls.calculated_withdrawn) as calculated_balance,
    w.total_received as stored_received,
    ls.calculated_received as calculated_received,
    w.total_withdrawn as stored_withdrawn,
    ls.calculated_withdrawn as calculated_withdrawn,
    (w.balance - (ls.calculated_received - ls.calculated_withdrawn)) as balance_discrepancy
FROM public.ngo_profiles n
JOIN public.ngo_wallets w ON n.id = w.ngo_id
LEFT JOIN ledger_summary ls ON n.id = ls.ngo_id
WHERE ABS(w.balance - (COALESCE(ls.calculated_received, 0) - COALESCE(ls.calculated_withdrawn, 0))) > 0.01;

-- If this query returns rows, the system has a data integrity failure.
