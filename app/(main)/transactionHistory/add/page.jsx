import { getUserAccounts } from "@/actions/dashboard";
import { defaultCategories } from "@/data/categories";
import { AddBulk_Transactions } from "../_components/bulk-transaction-form";
import { getTransaction } from "@/actions/bulktransaction";

export default async function AddBulkTransactions({ searchParams }) {
  const accounts = await getUserAccounts();
  let initialData = null;

  return (
    <div className="max-w-3xl mx-auto px-5">
      <div className="flex justify-center md:justify-normal mb-8">
        <h1 className="text-5xl gradient-title ">Add Transactions from PDF</h1>
      </div>
      <AddBulk_Transactions
        accounts={accounts}
      />
    </div>
  );
}
