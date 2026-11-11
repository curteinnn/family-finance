BEGIN;

-- Stop before changing data if the existing rows violate the new role rules.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM "users"
    WHERE "role" = 'ADMIN' AND "familyId" IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Role-profile migration: ADMIN users must not have a familyId';
  END IF;

  IF EXISTS (
    SELECT 1 FROM "users"
    WHERE "role" IN ('PARENT', 'CHILD') AND "familyId" IS NULL
  ) THEN
    RAISE EXCEPTION 'Role-profile migration: PARENT and CHILD users require a family';
  END IF;

  IF EXISTS (
    SELECT 1 FROM "users"
    WHERE "role" = 'PARENT'
    GROUP BY "familyId"
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Role-profile migration: a family has more than one PARENT';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM "wallets" w
    JOIN "users" u ON u."id" = w."userId"
    WHERE u."role" <> 'CHILD'
       OR u."familyId" IS DISTINCT FROM w."familyId"
  ) THEN
    RAISE EXCEPTION 'Role-profile migration: wallet owner or family does not match';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM "fund_transfers" t
    JOIN "users" sender ON sender."id" = t."senderId"
    JOIN "wallets" w ON w."id" = t."walletId"
    LEFT JOIN "users" confirmer ON confirmer."id" = t."confirmedById"
    WHERE sender."role" <> 'PARENT'
       OR sender."familyId" IS DISTINCT FROM t."familyId"
       OR w."familyId" IS DISTINCT FROM t."familyId"
       OR (t."confirmedById" IS NOT NULL AND (
         confirmer."role" <> 'CHILD'
         OR confirmer."id" IS DISTINCT FROM w."userId"
       ))
  ) THEN
    RAISE EXCEPTION 'Role-profile migration: transfer parent, child, wallet, or family does not match';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM "expenses" e
    JOIN "users" creator ON creator."id" = e."createdById"
    JOIN "wallets" w ON w."id" = e."walletId"
    WHERE creator."role" <> 'CHILD'
       OR creator."id" IS DISTINCT FROM w."userId"
       OR creator."familyId" IS DISTINCT FROM e."familyId"
       OR w."familyId" IS DISTINCT FROM e."familyId"
  ) THEN
    RAISE EXCEPTION 'Role-profile migration: expense child, wallet, or family does not match';
  END IF;
END $$;

CREATE TABLE "admins" (
  "userId" UUID NOT NULL,
  "name" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "admins_pkey" PRIMARY KEY ("userId")
);

CREATE TABLE "parents" (
  "userId" UUID NOT NULL,
  "familyId" UUID NOT NULL,
  "name" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "parents_pkey" PRIMARY KEY ("userId"),
  CONSTRAINT "parents_familyId_key" UNIQUE ("familyId")
);

CREATE TABLE "children" (
  "userId" UUID NOT NULL,
  "familyId" UUID NOT NULL,
  "name" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "children_pkey" PRIMARY KEY ("userId")
);

INSERT INTO "admins" ("userId", "name", "createdAt", "updatedAt")
SELECT "id", "name", "createdAt", "updatedAt"
FROM "users"
WHERE "role" = 'ADMIN';

INSERT INTO "parents" ("userId", "familyId", "name", "createdAt", "updatedAt")
SELECT "id", "familyId", "name", "createdAt", "updatedAt"
FROM "users"
WHERE "role" = 'PARENT';

INSERT INTO "children" ("userId", "familyId", "name", "createdAt", "updatedAt")
SELECT "id", "familyId", "name", "createdAt", "updatedAt"
FROM "users"
WHERE "role" = 'CHILD';

ALTER TABLE "admins"
  ADD CONSTRAINT "admins_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "parents"
  ADD CONSTRAINT "parents_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "parents_familyId_fkey"
  FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "children"
  ADD CONSTRAINT "children_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "children_familyId_fkey"
  FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE INDEX "children_familyId_idx" ON "children"("familyId");

ALTER TABLE "wallets" ADD COLUMN "childId" UUID;
UPDATE "wallets" SET "childId" = "userId";

-- Existing child accounts without a wallet receive their required primary wallet.
INSERT INTO "wallets" (
  "id", "familyId", "childId", "name", "isActive", "createdAt", "updatedAt"
)
SELECT
  gen_random_uuid(), u."familyId", u."id", 'Wallet Utama', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "users" u
WHERE u."role" = 'CHILD'
  AND NOT EXISTS (
    SELECT 1 FROM "wallets" w WHERE w."childId" = u."id"
  );

ALTER TABLE "wallets" ALTER COLUMN "childId" SET NOT NULL;
CREATE UNIQUE INDEX "wallets_childId_key" ON "wallets"("childId");
ALTER TABLE "wallets"
  ADD CONSTRAINT "wallets_childId_fkey"
  FOREIGN KEY ("childId") REFERENCES "children"("userId") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "fund_transfers"
  ADD COLUMN "parentId" UUID,
  ADD COLUMN "childId" UUID,
  ADD COLUMN "confirmedByChildId" UUID;

UPDATE "fund_transfers" t
SET "parentId" = t."senderId",
    "childId" = w."userId",
    "confirmedByChildId" = t."confirmedById"
FROM "wallets" w
WHERE w."id" = t."walletId";

ALTER TABLE "fund_transfers"
  ALTER COLUMN "parentId" SET NOT NULL,
  ALTER COLUMN "childId" SET NOT NULL;

ALTER TABLE "fund_transfers"
  DROP CONSTRAINT "fund_transfers_senderId_fkey",
  DROP CONSTRAINT "fund_transfers_confirmedById_fkey",
  ADD CONSTRAINT "fund_transfers_parentId_fkey"
    FOREIGN KEY ("parentId") REFERENCES "parents"("userId") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "fund_transfers_childId_fkey"
    FOREIGN KEY ("childId") REFERENCES "children"("userId") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "fund_transfers_confirmedByChildId_fkey"
    FOREIGN KEY ("confirmedByChildId") REFERENCES "children"("userId") ON DELETE RESTRICT ON UPDATE CASCADE;

DROP INDEX "fund_transfers_senderId_idx";
CREATE INDEX "fund_transfers_parentId_idx" ON "fund_transfers"("parentId");
CREATE INDEX "fund_transfers_childId_createdAt_idx" ON "fund_transfers"("childId", "createdAt");

ALTER TABLE "fund_transfers"
  DROP COLUMN "senderId",
  DROP COLUMN "confirmedById";

ALTER TABLE "expenses" ADD COLUMN "childId" UUID;
UPDATE "expenses" e
SET "childId" = w."userId"
FROM "wallets" w
WHERE w."id" = e."walletId";

ALTER TABLE "expenses" ALTER COLUMN "childId" SET NOT NULL;
ALTER TABLE "expenses"
  DROP CONSTRAINT "expenses_createdById_fkey",
  ADD CONSTRAINT "expenses_childId_fkey"
    FOREIGN KEY ("childId") REFERENCES "children"("userId") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "expenses"
  RENAME COLUMN "voidedById" TO "voidedByUserId";

ALTER TABLE "expenses"
  RENAME CONSTRAINT "expenses_voidedById_fkey" TO "expenses_voidedByUserId_fkey";
CREATE INDEX "expenses_childId_spentAt_idx" ON "expenses"("childId", "spentAt");

ALTER TABLE "expenses" DROP COLUMN "createdById";

ALTER TABLE "wallets"
  DROP CONSTRAINT "wallets_userId_fkey";
DROP INDEX "wallets_userId_key";
ALTER TABLE "wallets" DROP COLUMN "userId";

ALTER TABLE "users"
  DROP CONSTRAINT "users_familyId_fkey";
DROP INDEX "users_familyId_role_idx";
ALTER TABLE "users"
  DROP COLUMN "familyId",
  DROP COLUMN "name";

COMMIT;
