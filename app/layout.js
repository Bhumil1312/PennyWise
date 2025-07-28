import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Work_Sans } from "next/font/google";
import Header from "@/components/header";
import { ClerkProvider } from "@clerk/nextjs";
import { Toaster } from "sonner";

const workSans = Work_Sans({ subsets: ["latin"], weight: ["400", "600", "700"] });


export const metadata = {
  title: "PennyWise",
  description: "Personal Finance Assistant. Track, manage and analyze your finances, with receipt and PDF import, graphs and multi-user support.",
  applicationName: "PennyWise: Personal Finance Assistant",
  keywords: [
    "personal finance",
    "expense tracker",
    "income tracking",
    "receipt scanner",
    "financial dashboards",
    "budget planner",
    "web app",
    "PDF bank statement import",
    "finance manager"
  ],
  authors: [{ name: "Your Company or Developer Name", url: "https://your-website.com" }],
  viewport: {
    width: "device-width",
    initialScale: 1,
  },
  themeColor: "#ffffff",
};


export default function RootLayout({ children }) {
  return (
     <ClerkProvider>
      <html lang="en">
        {/* <head>
          <link rel="icon" href="/logo-sm.png" sizes="any" />
        </head> */}
        <body className={`${workSans.className}`}>
          <Header />
          <main className="min-h-screen">{children}</main>
          <Toaster richColors/>

          {/* Footer */}
          <footer className="bg-gray/50 backdrop-blur-md py-12 border-t">
            <div className="container mx-auto px-40 md:flex md:items-center md:justify-between">
              {/* Brand & tag */}
              <div className="mb-6 md:mb-0 text-left md:text-left">
                <img src="/PennyWise.svg" alt="PennyWise Logo" />
                <p className="text-gray-500 text-sm mt-2">
                  Your personal hub for mastering money management.
                </p>
              </div>
              {/* Links organized into two columns */}
              <div className="flex gap-10 md:gap-16">
                {/* Main Site Links - Vertical list */}
                <nav className="flex flex-col gap-4 text-gray-600">
                  <a href="https://www.youtube.com/playlist?list=PLgToSABL-x9L29Ipv3QR3-c04SAjHhEhG" className="hover:text-white transition">Watch Demo</a>
                  <a href="/#features" className="hover:text-white transition">Features</a>
                  <a href="/pricing" className="hover:text-white transition">Pricing</a>
                  <a href="/pageUnderDev" className="hover:text-white transition">Contact</a>
                </nav>
                {/* Policy & Terms - Vertical list */}
                <nav className="flex flex-col gap-4 text-xs text-gray-400">
                  <a href="/pageUnderDev" className="hover:text-white">Privacy Policy</a>
                  <a href="/pageUnderDev" className="hover:text-white">Terms</a>
                </nav>
              </div>
            </div>
            <div className="border-t mt-10 pt-6 text-sm text-center text-gray-400 z-10">
              <span>
                &copy; {new Date().getFullYear()} PennyWise. All rights reserved.
              </span>
            </div>
          </footer>

        </body>
      </html>
    </ClerkProvider>
  );
}
