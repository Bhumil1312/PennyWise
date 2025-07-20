'use client';

import React, { useState } from 'react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Loader2 } from 'lucide-react';
import { toast } from 'sonner';

export function BulkReceiptScanner({ onScanComplete }) {
  const [loading, setLoading] = useState(false);

  const handlePDFUpload = async (event) => {
    const file = event.target.files[0];
    if (!file || file.type !== 'application/pdf') {
      toast.error('Please upload a valid PDF file');
      return;
    }

    const formData = new FormData();
    formData.append('file', file);

    setLoading(true);
    try {
      const res = await fetch('/api/scan-receipt', {
        method: 'POST',
        body: formData,
      });

      const data = await res.json();
      if (res.ok && Array.isArray(data.transactions)) {
        onScanComplete(data.transactions);
        toast.success(`Scanned ${data.transactions.length} transactions`);
      } else {
        toast.error('Failed to parse PDF');
      }
    } catch (err) {
      console.error(err);
      toast.error('Error scanning receipt');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-2">
      <label className="text-sm font-medium">Upload PDF Bank Statement</label>
      <Input type="file" accept="application/pdf" onChange={handlePDFUpload} />
      {loading && (
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          Scanning with Gemini...
        </div>
      )}
    </div>
  );
}
