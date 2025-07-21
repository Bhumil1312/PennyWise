"use client";

// At the very top of bulk-transaction-form.jsx:

import React, { useState, useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { CalendarIcon, Loader2 } from "lucide-react";
import { format } from "date-fns";
import { useRouter, useSearchParams } from "next/navigation";
import useFetch from "@/hooks/use-fetch";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import { CreateAccountDrawer } from "@/components/create-account-drawer";
import { cn } from "@/lib/utils";
import { createTransaction, updateTransaction } from "@/actions/bulktransaction";
import { transactionSchema } from "@/app/lib/schema";
import { PDFScanner } from "./bulk-receipt-scanner";

export function AddTransactionForm({ accounts, categories, editMode = false, initialData = null }) {
  const [transactions, setTransactions] = useState([]);
const [selectedAccountId, setSelectedAccountId] = useState(
  accounts.find((ac) => ac.isDefault)?.id
);
const [selectedCategory, setSelectedCategory] = useState("shopping");
const [importing, setImporting] = useState(false);
const router = useRouter();

  const {
    register,
    handleSubmit,
    formState: { errors },
    watch,
    setValue,
    getValues,
    reset,
  } = useForm({
    resolver: zodResolver(transactionSchema),
    defaultValues:
      editMode && initialData
        ? {
            type: initialData.type,
            amount: initialData.amount.toString(),
            description: initialData.description,
            accountId: initialData.accountId,
            category: initialData.category,
            date: new Date(initialData.date),
            isRecurring: initialData.isRecurring,
            ...(initialData.recurringInterval && {
              recurringInterval: initialData.recurringInterval,
            }),
          }
        : {
            type: "EXPENSE",
            amount: "",
            description: "",
            accountId: accounts.find((ac) => ac.isDefault)?.id,
            date: new Date(),
            isRecurring: false,
          },
  });

  const {
    loading: transactionLoading,
    fn: transactionFn,
    data: transactionResult,
  } = useFetch(editMode ? updateTransaction : createTransaction);

  const onSubmit = (data) => {
    const formData = {
      ...data,
      amount: parseFloat(data.amount),
    };

    if (editMode) {
      transactionFn(editId, formData);
    } else {
      transactionFn(formData);
    }
  };

  const handleScanComplete = (data) => {
  if (Array.isArray(data.transactions)) {
    setTransactions(data.transactions);
    toast.success(`Scanned ${data.transactions.length} transactions`);
  } else {
    toast.error("Could not parse scanned PDF.");
  }
};

  useEffect(() => {
    if (transactionResult?.success && !transactionLoading) {
      toast.success(
        editMode
          ? "Transaction updated successfully"
          : "Transaction created successfully"
      );
      reset();
      router.push(`/account/${transactionResult.data.accountId}`);
    }
  }, [transactionResult, transactionLoading, editMode]);

  const type = watch("type");
  const isRecurring = watch("isRecurring");
  const date = watch("date");

  const filteredCategories = categories.filter(
    (category) => category.type === type
  );

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      {/* PDF Scanner - Only show in create mode */}
      <PDFScanner onScanComplete={handleScanComplete} />

{/* Account & Category Selectors */}
{transactions.length > 0 && (
  <div className="space-y-4 mt-6">
    <div className="grid md:grid-cols-2 gap-4">
      <div>
        <label className="text-sm font-medium">Select Account</label>
        <Select onValueChange={setSelectedAccountId} defaultValue={selectedAccountId}>
          <SelectTrigger>
            <SelectValue placeholder="Choose account" />
          </SelectTrigger>
          <SelectContent>
            {accounts.map((account) => (
              <SelectItem key={account.id} value={account.id}>
                {account.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div>
        <label className="text-sm font-medium">Select Category</label>
        <Select onValueChange={setSelectedCategory} defaultValue={selectedCategory}>
          <SelectTrigger>
            <SelectValue placeholder="Choose category" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="shopping">Shopping</SelectItem>
            <SelectItem value="bills">Bills</SelectItem>
            <SelectItem value="food">Food</SelectItem>
            <SelectItem value="other-expense">Other</SelectItem>
          </SelectContent>
        </Select>
      </div>
    </div>

    {/* Transaction Preview */}
    <div className="overflow-x-auto border rounded-md">
      <table className="w-full text-sm">
        <thead className="bg-gray-100">
          <tr>
            <th className="p-2 text-left">Date</th>
            <th className="p-2 text-left">Amount</th>
            <th className="p-2 text-left">Type</th>
            <th className="p-2 text-left">Description</th>
          </tr>
        </thead>
        <tbody>
          {transactions.map((txn, idx) => (
            <tr key={idx} className="border-t">
              <td className="p-2">{txn.date}</td>
              <td className="p-2">{txn.amount}</td>
              <td className="p-2">{txn.type}</td>
              <td className="p-2">{txn.description}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>

    {/* Import Button */}
    <Button
      className="w-full mt-4"
      onClick={async () => {
        setImporting(true);
        try {
          for (const txn of transactions) {
            await createTransaction({
              accountId: selectedAccountId,
              category: selectedCategory,
              type: txn.type,
              amount: parseFloat(txn.amount),
              date: new Date(txn.date),
              description: txn.description,
              isRecurring: false,
            });
          }
          toast.success(`Imported ${transactions.length} transactions!`);
          router.push(`/account/${selectedAccountId}`);
        } catch (err) {
          console.error(err);
          toast.error("Import failed.");
        } finally {
          setImporting(false);
        }
      }}
      disabled={importing}
    >
      {importing ? "Importing..." : "Import All Transactions"}
    </Button>
  </div>
)}
    </form>
  );
}
