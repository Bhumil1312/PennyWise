"use server";

import { auth } from "@clerk/nextjs/server";
import { db } from "@/lib/prisma";
import { revalidatePath } from "next/cache";
import { GoogleGenerativeAI } from "@google/generative-ai";
import aj from "@/lib/arcjet";
import { request } from "@arcjet/next";

const genAI = new GoogleGenerativeAI(process.env.GOOGLE_GENERATIVE_AI_API_KEY);

// Fix incomplete JSON response from Gemini and ensure valid JSON format for jason parsing
function fixIncompleteJson(rawStr) {
  if (!rawStr || typeof rawStr !== 'string') return rawStr;
  let str = rawStr
  .replace(/^```json\s*/, "")
    .replace(/```$/, "")
    .trim();
  const transactionsStartIndex = str.indexOf('"transactions": [');
  if (transactionsStartIndex === -1) {
    return str;
  }

  const prefix = str.substring(0, transactionsStartIndex + '"transactions": ['.length);
  let arrayContent = str.substring(transactionsStartIndex + '"transactions": ['.length);
  let braceStack = [];
  let lastValidIndex = -1;

  for (let i = 0; i < arrayContent.length; i++) {
    const char = arrayContent[i];
    if (char === '{') {
      braceStack.push(i);
    } else if (char === '}') {
      if (braceStack.length > 0) {
        braceStack.pop();
        if (braceStack.length === 0) {
          lastValidIndex = i;
        }
      }
    }
  }

  if (lastValidIndex === -1) {
    return prefix + '] }';
  }

  let cleanedArrayContent = arrayContent.substring(0, lastValidIndex + 1);
  cleanedArrayContent = cleanedArrayContent.trim();
  if (cleanedArrayContent.endsWith(',')) {
    cleanedArrayContent = cleanedArrayContent.slice(0, -1);
  }
  return prefix + cleanedArrayContent + '] }';
}

// Scan PDF
export async function scanPDF(file) {
  try {
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    // Convert File to ArrayBuffer
    const arrayBuffer = await file.arrayBuffer();
    // Convert ArrayBuffer to Base64
    const base64String = Buffer.from(arrayBuffer).toString("base64");

    const prompt = `
    Analyze this transactions (eg.bank statement) PDF containing a table of transactions. Extract all transactions in JSON format.
    Return an object with a "transactions" property that is an array of transactions.
    Each transaction should have these fields:
      - "category": string,
      - "type": string,
      - "amount": number,
      - "date": Date,
      - "description": string

    Category should be from this list(select based on notes or description of transaction/ if not then Other ...):
    ["Salary","Freelance","Investments","Business","Rental","Other Income"] and then set type to INCOME.
    or ["Housing","Transportation","Groceries","Utilities","Entertainment","Food","Shopping","Healthcare","Education","Personal Care","Travel","Insurance","Gifts & Donations","Bills & Fees","Other Expenses"] and then set type to EXPENSE.

    Here is the expected JSON format:

    {
      "transactions": [
        {
          "category": "Business",
          "type": "INCOME",
          "amount": 1234.99,
          "date": "2025-06-25",
          "description": "Payment from client"
        },
        { ... }, // more transactions
      ]
    }

    If the PDF cannot be parsed or no transactions exist, return an empty object.
    Only respond with valid JSON.
  `;


    const result = await model.generateContent([
      {
        inlineData: {
          data: base64String,
          mimeType: file.type,
        },
      },
      prompt,
    ]);

    const response = await result.response;
    const text = response.text();
    console.log("Gemini raw response:", text);
    const fixedText = fixIncompleteJson(text);

    try {
      const data = JSON.parse(fixedText);
      return data;
    } catch (parseError) {
      console.error("Error parsing JSON response:", parseError);
      throw new Error("Invalid response format from Gemini");
    }
  } catch (error) {
    console.error("Error scanning PDF:", error);
    throw new Error("Failed to scan PDF");
  }
}

//Add Bulk Transactions
export async function createBulkTransactions( accountId, transactions) {
  try {
    // Fetch user (authorization)
    const { userId } = await auth();
    if (!userId) throw new Error("Unauthorized");
    
    // Get request data for ArcJet
    const req = await request();
    // Check rate limit
    const decision = await aj.protect(req, {
      userId,
      requested: 1, // Specify how many tokens to consume
    });
    if (decision.isDenied()) {
      if (decision.reason.isRateLimit()) {
        const { remaining, reset } = decision.reason;
        console.error({
          code: "RATE_LIMIT_EXCEEDED",
          details: {
            remaining,
            resetInSeconds: reset,
          },
        });
        throw new Error("Too many requests. Please try again later.");
      }
      throw new Error("Request blocked");
    }
    const user = await db.user.findUnique({
      where: { clerkUserId: userId },
    });

    if (!user) {
      throw new Error("User not found");
    }

    // Fetch account and validate ownership
    const account = await db.account.findUnique({
      where: {
        id: accountId,
        userId: user.id,
      },
    });

    if (!account) {
      throw new Error("Account not found");
    }

    // Calculate new balance after adding all transactions
    let totalBalance = account.balance.toNumber();
    for (const txn of transactions) {
      const amountChange = txn.type === "EXPENSE" ? -parseFloat(txn.amount) : parseFloat(txn.amount);
      totalBalance += amountChange;
    }

    // Prepare transaction data with userId and some defaults if needed
    const txData = transactions.map((txn) => ({
      ...txn,
      userId: user.id,
      status: "COMPLETED",
      createdAt: txn.date,
      updatedAt: txn.date,
    }));

    // Perform bulk insert inside a transaction and update balance
    await db.$transaction(async (tx) => {
      await tx.transaction.createMany({ data: txData });
      await tx.account.update({
        where: { id: accountId },
        data: { balance: totalBalance },
      });
    });
    revalidatePath("/dashboard");
    revalidatePath(`/account/${accountId}`);

    return { success: true, data: { accountId, count: transactions.length } };
  } catch (error) {
    throw new Error(error.message);
  }
}
