import { Inngest } from "inngest";

export const inngest = new Inngest({
  id: "PennyWise", // Unique app ID
  name: "PennyWise",
  retryFunction: async (attempt) => ({
    delay: Math.pow(2, attempt) * 1000, // Exponential backoff
    maxAttempts: 2,
  }),
});
