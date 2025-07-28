-- CreateEnum
CREATE TYPE "SubscriptionTier" AS ENUM ('FREE', 'PRO', 'PREMIUM');

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "quotaPeriodStart" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "subscription" "SubscriptionTier" NOT NULL DEFAULT 'FREE',
ADD COLUMN     "usageQuota" INTEGER NOT NULL DEFAULT 0;
