
import { auth } from '@clerk/nextjs/server';
import { db } from '@/lib/prisma';

const QUOTA_LIMITS = {
  FREE: 5,
  PRO: 500,
  PREMIUM: Infinity,
};

// Helper function to add a month to a date
const addMonths = (date, months) => {
  const d = new Date(date);
  d.setMonth(d.getMonth() + months);
  return d;
};

export const checkQuota = async () => {
  const { userId } = await auth();
  console.log("Authenticated userId:", userId);
  if (!userId) throw new Error("Unauthorized");

  const user = await db.user.findUnique({
    where: { clerkUserId: userId },
    select: { 
      subscription: true, 
      usageQuota: true, 
      quotaPeriodStart: true 
    },
  });

  if (!user) {
    return { allowed: false, error: 'User not found' };
  }

  const { subscription, usageQuota, quotaPeriodStart } = user;
  const now = new Date();
  const nextBillingDate = addMonths(quotaPeriodStart, 1);

  // Check if the billing period has reset
  if (now >= nextBillingDate) {
    // Reset quota and update the start date for the new period
    await db.user.update({
      where: { clerkUserId: userId },
      data: { usageQuota: 0, quotaPeriodStart: now },
    });
    // After reset, the user's quota is 0, so they are allowed
    return { allowed: true };
  }

  const limit = QUOTA_LIMITS[subscription];

  if (usageQuota >= limit) {
    return { 
      allowed: false, 
      error: `Usage limit of ${limit} reached. Please upgrade.` 
    };
  }

  return { allowed: true };
};

export const incrementQuota = async () => {
  const { userId } = await auth();
  console.log("Authenticated userId:", userId);
  if (!userId) throw new Error("Unauthorized");

  await db.user.update({
    where: { clerkUserId: userId },
    data: { usageQuota: { increment: 1 } },
  });

  return { success: true };
};
