import {
  DollarSign,
  List,
  Cloud,
  BarChart2,
  UserCheck,
  UploadCloud,
  FileText,
  Users,
  TrendingUp,
} from "lucide-react";

// Features Data
export const featuresData = [
  {
    icon: <DollarSign className="h-8 w-8 " />,
    title: "Quick Add Income & Expenses",
    description:
      "Log your everyday transactions in seconds. Input forms are optimized for speed and simplicity.",
  },
  {
    icon: <List className="h-8 w-8 " />,
    title: "Detailed Transaction List & Filters",
    description: "Review every expense or income with date-range filters, sorting, and powerful search for full control.",
  },
  {
    icon: <BarChart2 className="h-8 w-8 " />,
    title: "Interactive Analytics & Insights",
    description: "Drill into your spending trends, visualize cash flow, and identify opportunities to save with intuitive graphs.",
  },
  {
    icon: <FileText className="h-8 w-8 " />,
    title: "Smart Receipt & PDF Scanner",
    description: "Extract data from paper receipts or bank statement PDFs — seamlessly add transactions, no typing needed.",
  },
  {
    icon: <Users className="h-8 w-8 " />,
    title: "Collaborative Accounts",
    description: "Invite family or partners into your finance dashboard. Each user’s data is secure and personalized.",
  },
  {
    icon: <Cloud className="h-8 w-8 " />,
    title: "Safe & Secure Storage",
    description: "Automatic backups protect your information, encrypted in the cloud for peace of mind.",
  },
];

// How PennyWise Works
export const  howItWorksData = [
  {
    icon: <UserCheck className="h-8 w-8 "/>,
    title: "Get Started Instantly",
    description: "Sign up in seconds, invite others, and access your dashboard from any device.",
  },
  {
    icon: <UploadCloud className="h-8 w-8 "/>,
    title: "Add or Import Transactions",
    description: "Quickly create transactions or import from scanned receipts and bank statement PDFs.",
  },
  {
    icon: <TrendingUp className="h-8 w-8 "/>,
    title: "Analyze & Succeed",
    description: "Visualize patterns, track budgets, and get actionable financial insights to help you thrive.",
  },
];