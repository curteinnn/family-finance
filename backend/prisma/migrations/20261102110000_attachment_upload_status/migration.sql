CREATE TYPE "AttachmentStatus" AS ENUM ('PENDING', 'AVAILABLE');

ALTER TABLE "attachments"
  ADD COLUMN "status" "AttachmentStatus" NOT NULL DEFAULT 'AVAILABLE';

ALTER TABLE "attachments"
  ALTER COLUMN "status" SET DEFAULT 'PENDING';
