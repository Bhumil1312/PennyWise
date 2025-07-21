# PennyWise

**A Modern Personal Finance Tracker**  
**Assignment Submission – Typeface AI Recruitment (Full Stack)**  
Developer: [Bhumil1312](https://github.com/Bhumil1312)

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Setup Instructions](#setup-instructions)
- [Development & Run Commands](#development--run-commands)
- [Git Workflow Instructions](#git-workflow-instructions)
- [Assignment Deliverables](#assignment-deliverables)
- [Limitations](#limitations)
- [Demo](#demo)
- [Note to Interviewer](#note-to-interviewer)
- [Contact](#contact)

---

## Overview

**PennyWise** is a full-featured personal finance web platform that allows users to manage multiple accounts, monitor spending, categorize financial activity, upload receipts, receive automated notifications, and perform AI-assisted document parsing.

This project was developed as part of the interview assignment for the Typeface AI hiring process and was designed to demonstrate proficiency in both full-stack development and product implementation.

---

## Features

### Core Functionality

- **Multi-Account Support**  
  Manage separate budgets and dashboards for each account.

- **Categorized Income & Expenses**  
  Add/edit categorized transactions with form validation.

- **Date-Filtered Transactions**  
  View transactions by specific date ranges.

- **Persistent Data Storage**  
  Stores data in PostgreSQL via Prisma ORM.

- **Secure Multi-User Access**  
  Account-level isolation via Clerk.dev authentication.

---

### Advanced & Bonus Features

- **Receipt Upload with AI Parsing**  
  Upload POS receipts → auto-extract details with Gemini AI.

- **Automated Email Alerts (85% Spending)**  
  Users get alerted when budget usage reaches 85%.

- **Bulk PDF Statement Import (In Progress)**  
  Extract multiple transactions from uploaded PDFs using LLM.

- **Visual Dashboards + Charts**  
  See trends, by category & over time.

- **Paginated Listings & APIs**  
  APIs for transaction listing and filtering with pagination.

---

## Technology Stack

| Layer         | Details                                           |
|---------------|---------------------------------------------------|
| Frontend      | Next.js (App Router), Tailwind CSS                |
| UI/UX         | Shadcn/UI, React Hook Form, Zod                   |
| Backend       | Next.js API Routes                                |
| AI Integration| Google Gemini API for OCR/doc parsing             |
| ORM/Database  | Prisma + PostgreSQL                               |
| Auth          | Clerk.dev                                         |
| Email         | Nodemailer (SMTP), Local email testing via Devbox |
| Jobs/Events   | Inngest                                           |

---

## Setup Instructions

### Prerequisites

- Node.js 18+
- A PostgreSQL database
- Gemini API Key
- Clerk project/API keys
- SMTP credentials (for alerts)

### Installation

1. Clone the repository and install dependencies:
    ```
    git clone https://github.com/Bhumil1312/PennyWise.git
    cd PennyWise
    npm install
    ```

2. Copy environment configuration:
    ```
    cp .env.example .env.local
    ```

3. Set environment variables in `.env.local`:
    - `DATABASE_URL`
    - `CLERK_SECRET_KEY`
    - `CLERK_PUBLISHABLE_KEY`
    - `GEMINI_API_KEY`
    - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`
    - `NEXT_PUBLIC_CLERK_FRONTEND_API` (optional)

4. Set up Prisma DB:
    ```
    npx prisma migrate dev
    npx prisma generate
    ```

---

## Development & Run Commands

You’ll need multiple terminals to run everything locally.

### 1. Run the main app
npm run dev

text

### 2. Run Inngest Dev Server (for email triggers & background jobs)
npx inngest-cli@latest dev

make sure your '/api/inngest' source is working
text

> ⚠️ If you don’t have `inngest-cli` installed:
> ```
> npm install -g inngest-cli
> ```

### 3. Run Email Testing Tool (like MailDev or any SMTP dev server)
npm run email

text

This enables you to test triggered emails (e.g., 80% budget warning).

---

## Git Workflow Instructions

To work on custom features or collaborate:

### Create & Switch to a Branch:
git checkout -b feature/my-new-feature

text

### Add, Commit & Push:
git add .
git commit -m "Added new income chart component"
git push -u origin feature/my-new-feature

text

Once pushed, collaborators and reviewers (including interviewers) can check your work in that branch.

---

## Assignment Deliverables

| Feature / Requirement                                  | Status             |
|--------------------------------------------------------|--------------------|
| Add/Edit income and expense entries                    | ✅ Implemented     |
| View entries by date range                             | ✅ Implemented     |
| Charts by category and over time                       | ✅ Implemented     |
| Upload POS receipts and extract data                   | ✅ Done (Gemini AI)|
| Upload & parse PDF (batch transactions)                | ⚠️ In Progress     |
| APIs separate from frontend                            | ✅ Implemented     |
| Persistent PostgreSQL storage                          | ✅ With Prisma     |
| Auth for users and data isolation                      | ✅ With Clerk      |
| Bonus: Email alerts at 85% budget                      | ✅ Implemented     |
| Bonus: Paginated transactions                          | ✅ Done            |

---

## Limitations

- **PDF Parser Still Evolving**  
  Gemini AI output from PDF tables can be inconsistent. I'm working on structuring the response into clean transaction arrays.

- **Edge Case Accuracy (OCR)**  
  Faded or skewed receipts sometimes confuse Gemini’s OCR, resulting in partially incorrect data.

- **Live Hosting Option**  
  This README assumes local dev setup. A production-ready deployment config (e.g., Vercel or Render) can be added easily.

---

## Demo

Watch a walkthrough of all features here:  
👉 [PennyWise Demo Playlist – YouTube](https://www.youtube.com/playlist?list=INSERT_YOUR_PLAYLIST_ID_HERE)

---

## Note to Interviewer

> **Hi there!**  
> I'm actively working on additional enhancements and polishing features beyond the assignment scope on my **personal development branch**.  
> These include:
>
> - More accurate parsing of banks’ PDFs using Gemini Pro
> - Unified dashboard widgets (metrics, 7-day trends)
> - Performance cleanups on larger datasets
>
> You’re welcome to browse that work as well:
>
> ```
> Branch: /personal
> ```

Let me know if you’d like a preview or demo of that work.

## Contact

For questions, feedback, or demo requests, please [open an issue](https://github.com/Bhumil1312/PennyWise/issues) or contact [@Bhumil1312](https://github.com/Bhumil1312).

---
