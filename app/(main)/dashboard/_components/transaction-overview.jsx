"use client";

import { useState } from "react";
import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  Tooltip,
  Legend,
} from "recharts";
import { format } from "date-fns";
import { ArrowUpRight, ArrowDownRight } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { categoryColors } from "/data/categories";


function normalizeKey(name) {
  return name
    .toLowerCase()
    .replace(/[\s&]+/g, "-")
    .replace(/[^a-z0-9-]/g, "");
}

export function DashboardOverview({ accounts, transactions }) {
  const [selectedAccountId, setSelectedAccountId] = useState(
    accounts.find((a) => a.isDefault)?.id || accounts[0]?.id
  );

  const accountTransactions = transactions.filter(
    (t) => t.accountId === selectedAccountId
  );

  const recentTransactions = accountTransactions
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .slice(0, 5);

  const currentDate = new Date();

  const currentMonthExpenses = accountTransactions.filter((t) => {
    const transactionDate = new Date(t.date);
    return (
      t.type === "EXPENSE" &&
      transactionDate.getMonth() === currentDate.getMonth() &&
      transactionDate.getFullYear() === currentDate.getFullYear()
    );
  });

  const expensesByCategory = currentMonthExpenses.reduce((acc, transaction) => {
    const category = transaction.category || "Uncategorized";
    if (!acc[category]) {
      acc[category] = 0;
    }
    acc[category] += transaction.amount;
    return acc;
  }, {});

  const pieChartData = Object.entries(expensesByCategory).map(([category, amount]) => ({
    name: category,
    value: amount,
  }));

  const renderLabel = ({
    cx,
    cy,
    midAngle,
    innerRadius,
    outerRadius,
    percent,
    name,
    value,
  }) => {
    const RADIAN = Math.PI / 180;
    const radius = innerRadius + (outerRadius - innerRadius) * 0.6;
    const x = cx + radius * Math.cos(-midAngle * RADIAN);
    const y = cy + radius * Math.sin(-midAngle * RADIAN);

    return percent > 0.04 ? (
      <text
        x={x}
        y={y}
        fill="#222"
        textAnchor={x > cx ? "start" : "end"}
        dominantBaseline="central"
        fontSize={13}
        fontWeight={500}
      >
        {`${name}: $${value.toFixed(2)}`}
      </text>
    ) : null;
  };

  return (
    <section>
      <div className="container mx-auto px-4">
        <Card className="relative bg-gray-900/70 backdrop-blur-md border border-white/20 shadow-lg text-white overflow-hidden">
          <div className="absolute inset-0 pointer-events-none bg-gradient-to-br from-white/20 via-white/5 to-transparent" />
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-white">
              Transaction Overview
              <Select
                value={selectedAccountId}
                onValueChange={(v) => setSelectedAccountId(v)}
              >
                <SelectTrigger className="ml-auto w-48 text-base bg-gray-900/70 border border-white/20 text-white">
                  <SelectValue placeholder="Select Account" />
                </SelectTrigger>
                <SelectContent className="bg-gray-900/90 text-white border border-white/20">
                  {accounts.map((account) => (
                    <SelectItem key={account.id} value={account.id} className="text-white">
                      {account.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </CardTitle>
          </CardHeader>
          <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-8 text-white">
            {/* Pie Chart */}
            <div className="w-full h-64 flex items-center justify-center">
              {pieChartData.length === 0 ? (
                <p className="text-white/70 text-center">
                  No expenses this month
                </p>
              ) : (
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={pieChartData}
                      dataKey="value"
                      nameKey="name"
                      cx="50%"
                      cy="50%"
                      outerRadius={90}
                      innerRadius={50}
                      paddingAngle={1}
                      label={({ cx, cy, midAngle, innerRadius, outerRadius, percent, name, value }) => {
                        const RADIAN = Math.PI / 180;
                        const radius = innerRadius + (outerRadius - innerRadius) * 0.6;
                        const x = cx + radius * Math.cos(-midAngle * RADIAN);
                        const y = cy + radius * Math.sin(-midAngle * RADIAN);
                        return percent > 0.04 ? (
                          <text
                            x={x}
                            y={y}
                            fill="#fff"
                            textAnchor={x > cx ? "start" : "end"}
                            dominantBaseline="central"
                            fontSize={13}
                            fontWeight={500}
                          >
                            {`${name}: $${value.toFixed(2)}`}
                          </text>
                        ) : null;
                      }}
                      labelLine={false}
                    >
                      {pieChartData.map((entry, index) => {
                        const color =
                          categoryColors[normalizeKey(entry.name)] || "#23272a";
                        return (
                          <Cell key={`cell-${index}`} fill={color} />
                        );
                      })}
                    </Pie>
                    <Tooltip
                      formatter={(value) =>
                        `$${parseFloat(value).toLocaleString(undefined, {
                          minimumFractionDigits: 2,
                        })}`
                      }
                      contentStyle={{
                        backgroundColor: "#23272a",
                        color: "#fff",
                        border: "1px solid #fff",
                        borderRadius: "8px",
                      }}
                    />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </div>
            {/* Recent Transactions */}
            <div>
              <h3 className="font-semibold text-lg mb-4 text-white">
                Recent Transactions
              </h3>
              {recentTransactions.length === 0 ? (
                <p className="text-white/70">No recent transactions</p>
              ) : (
                <ul className="divide-y divide-white/20">
                  {recentTransactions.map((transaction, idx) => (
                    <li key={transaction.id || idx} className="py-3 flex items-center gap-3">
                      <span
                        className={cn(
                          "w-9 h-9 flex items-center justify-center rounded-md",
                          transaction.type === "INCOME"
                            ? "bg-green-500/20 text-green-300"
                            : "bg-red-500/20 text-red-300"
                        )}
                      >
                        {transaction.type === "INCOME" ? (
                          <ArrowUpRight className="w-5 h-5" />
                        ) : (
                          <ArrowDownRight className="w-5 h-5" />
                        )}
                      </span>
                      <div className="flex-1 min-w-0">
                        <div className="font-medium truncate text-white">
                          {transaction.description || "Untitled Transaction"}
                        </div>
                        <div className="text-sm text-white/80">
                          {format(new Date(transaction.date), "PP")}
                        </div>
                        <div className="text-xs text-white/60 mt-1">
                          {transaction.category}
                        </div>
                      </div>
                      <div
                        className={cn(
                          "font-bold text-lg ml-3",
                          transaction.type === "INCOME"
                            ? "text-green-300"
                            : "text-red-300"
                        )}
                      >
                        {transaction.type === "INCOME" ? "+" : "-"}$
                        {Math.abs(transaction.amount).toFixed(2)}
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </section>
  );
}
