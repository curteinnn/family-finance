ALTER TYPE "TransferStatus" ADD VALUE IF NOT EXISTS 'REJECTED';

ALTER TABLE "fund_transfers"
  ADD COLUMN "rejectedAt" TIMESTAMP(3),
  ADD COLUMN "rejectionReason" TEXT;
