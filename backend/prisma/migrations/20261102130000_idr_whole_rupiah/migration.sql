DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM "fund_transfers" WHERE "amount" <> TRUNC("amount")
  ) OR EXISTS (
    SELECT 1 FROM "expenses" WHERE "amount" <> TRUNC("amount")
  ) THEN
    RAISE EXCEPTION 'IDR migration stopped: fractional amounts exist; review and convert them explicitly before retrying';
  END IF;
END $$;

ALTER TABLE "fund_transfers"
  ALTER COLUMN "amount" TYPE DECIMAL(14, 0) USING "amount"::DECIMAL(14, 0);

ALTER TABLE "expenses"
  ALTER COLUMN "amount" TYPE DECIMAL(14, 0) USING "amount"::DECIMAL(14, 0);
