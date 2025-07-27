"use client";

import { useRef, useEffect } from "react";
import { Camera, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import useFetch from "@/hooks/use-fetch";
import { scanPDF } from "@/actions/bulktransaction";

export function PDFScanner({ onScanComplete }) {
  const fileInputRef = useRef(null);
  const {loading: scanPDFLoading,fn: scanPDFFn,data: scannedData} = useFetch(scanPDF);
  const handlePDFScan = async (file) => {
    if (file.size > 6 * 1024 * 1024) {
      toast.error("PDF size should be less than 6MB");
      return;
    }
    await scanPDFFn(file);
  };

  useEffect(() => {
    if (scannedData && !scanPDFLoading) {
      onScanComplete(scannedData);
      toast.success("PDF scanned successfully");
    }
  }, [scanPDFLoading, scannedData]);

  return (
    <div className="flex items-center gap-4">
      <input
        type="file"
        ref={fileInputRef}
        className="hidden"
        accept="application/pdf"
        capture="environment"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) handlePDFScan(file);
        }}
      />
      <Button
        type="button"
        variant="outline"
        className="w-full h-10 rounded-lg font-bold flex items-center justify-center animate-gradient-logo text-gray-800 hover:text-white"
        onClick={() => fileInputRef.current?.click()}
        disabled={scanPDFLoading}
      >
        {scanPDFLoading ? (
          <>
            <Loader2 className="mr-2 animate-spin" />
            <span>Scanning PDF...</span>
          </>
        ) : (
          <>
            <Camera className="mr-2" />
            <span>Upload, and Scan PDF with AI</span>
          </>
        )}
      </Button>
    </div>
  );
}
