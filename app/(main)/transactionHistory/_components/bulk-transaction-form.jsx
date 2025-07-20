'use client';

import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { BulkReceiptScanner } from './bulk-receipt-scanner';
import { toast } from 'sonner';
import { createTransaction } from '@/actions/transaction';

export function BulkTransactionForm({ accounts}) {
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(false);

  const handleScanComplete = (txnList) => {
    setTransactions(txnList);
  };

  const importAll = async () => {
    if (!transactions.length) return;
    const defaultAccountId = accounts.find((ac) => ac.isDefault)?.id;
    setLoading(true);

    try {
      for (const txn of transactions) {
        const payload = {
          ...txn,
          amount: parseFloat(txn.amount),
          accountId: defaultAccountId,
          date: new Date(txn.date),
          type: txn.type || 'EXPENSE',
          isRecurring: false,
        };
        await createTransaction(payload);
      }

      toast.success(`${transactions.length} transactions imported!`);
    } catch (error) {
      console.error(error);
      toast.error('Failed to import transactions');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card className="p-6">
      <CardContent className="space-y-6">
        <BulkReceiptScanner onScanComplete={handleScanComplete} />

        {transactions.length > 0 && (
          <>
            <div className="text-sm font-medium">
              {transactions.length} transactions found
            </div>
            <div className="h-[240px] overflow-auto border rounded-md p-2">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-muted-foreground border-b">
                    <th className="text-left py-1 px-2">Date</th>
                    <th className="text-left py-1 px-2">Amount</th>
                    <th className="text-left py-1 px-2">Type</th>
                    <th className="text-left py-1 px-2">Description</th>
                    <th className="text-left py-1 px-2">Category</th>
                  </tr>
                </thead>
                <tbody>
                  {transactions.map((txn, idx) => (
                    <tr key={idx} className="border-b">
                      <td className="py-1 px-2">{txn.date}</td>
                      <td className="py-1 px-2">{txn.amount}</td>
                      <td className="py-1 px-2">{txn.type}</td>
                      <td className="py-1 px-2">{txn.description}</td>
                      <td className="py-1 px-2">{txn.category}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Button onClick={importAll} disabled={loading}>
              {loading ? 'Importing...' : 'Import All Transactions'}
            </Button>
          </>
        )}
      </CardContent>
    </Card>
  );
}
