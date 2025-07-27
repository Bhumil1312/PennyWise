"use client";
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
import {Select,SelectContent,SelectItem,SelectTrigger,SelectValue} from "@/components/ui/select";
import {Popover,PopoverContent,PopoverTrigger} from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import { CreateAccountDrawer } from "@/components/create-account-drawer";
import { cn } from "@/lib/utils";
import { createBulkTransactions} from "@/actions/bulktransaction";
import { transactionSchema } from "@/app/lib/schema";
import { PDFScanner } from "./bulk-receipt-scanner";

export function AddBulk_Transactions({ accounts }) {
  const [transactions, setTransactions] = useState([]);
  const [selectedAccountId, setSelectedAccountId] = useState(accounts.find((ac) => ac.isDefault)?.id);
  const [importing, setImporting] = useState(false);
  const router = useRouter();
  const {register,handleSubmit,formState: { errors },watch,setValue,getValues,reset} = useForm({
    resolver: zodResolver(transactionSchema),
    defaultValues:{type: "EXPENSE",amount: "",description: "",accountId: accounts.find((ac) => ac.isDefault)?.id,date: new Date(),isRecurring: false}
  });
  const {loading: transactionLoading,fn: transactionFn,data: transactionResult} = useFetch(createBulkTransactions);

  const onSubmit = (data) => {
    const formData = {
      ...data,
      amount: parseFloat(data.amount),
    };
    transactionFn(formData);
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
      toast.success("Transactions updated successfully from PDF");
      reset();
      router.push(`/account/${transactionResult.data.accountId}`);
    }
  }, [transactionResult, transactionLoading]);

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      {/* PDF Scanner*/}
      <PDFScanner onScanComplete={handleScanComplete} />
      {/* Account Selectors */}
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
          </div>

          {/* Transaction Preview */}
          <div className="overflow-x-auto border rounded-md">
            <table className="w-full text-sm">
              <thead className="bg-gray-100 text-gray-1000">
                <tr>
                  <th className="p-2 text-left">Date</th>
                  <th className="p-2 text-left">Category</th>
                  <th className="p-2 text-left">Description</th>
                  <th className="p-2 text-left">Amount</th>
                  <th className="p-2 text-left">Type</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((txn, idx) => (
                  <tr key={idx} className="border-t">
                    <td className="p-2">{txn.date}</td>
                    <td className="p-2">{txn.category}</td>
                    <td className="p-2">{txn.description}</td>
                    <td className="p-2">{txn.amount}</td>
                    <td className="p-2">{txn.type}</td>
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
                const formattedTxns = transactions.map((txn) => ({
                accountId: selectedAccountId,
                category: txn.category,
                type: txn.type,
                amount: parseFloat(txn.amount),
                date: new Date(txn.date),
                description: txn.description,
                isRecurring: false,
              }));
              
              const result = await createBulkTransactions(selectedAccountId, formattedTxns);
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
