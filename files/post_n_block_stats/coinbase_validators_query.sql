SELECT 
  eth2."DepositContract_evt_DepositEvent".pubkey 
FROM 
  eth2."DepositContract_evt_DepositEvent" 
WHERE 
  eth2."DepositContract_evt_DepositEvent".evt_tx_hash in (
    SELECT 
      tx_hash 
    FROM 
      ethereum."traces" tr 
    WHERE 
      tr.block_number >= 11182202 
      AND tr."to" = '\x00000000219ab540356cBB839Cbe05303d7705Fa' 
      AND tr.success = TRUE 
      AND tr.FROM in (
        SELECT 
          ethereum.transactions.from 
        FROM 
          ethereum.transactions 
        where 
          ethereum.transactions.from in (
            SELECT 
              ethereum.transactions.from 
            FROM 
              ethereum.transactions 
            where 
              ethereum.transactions.to = '\x00000000219ab540356cBB839Cbe05303d7705Fa' 
            group by 
              ethereum.transactions.from 
            having 
              count(*) = 1
          ) 
          and ethereum.transactions.to = '\xA090e606E30bD747d4E6245a1517EbE430F0057e'
      )
  )
