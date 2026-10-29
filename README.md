# PennyWise

## India-first Flutter app

The mobile continuation lives in [`mobile/`](mobile). Start with [the working features and run instructions](docs/START_HERE.md), [the current architecture](docs/ARCHITECTURE_INDIA.md), and [the system-design learning guide](docs/SYSTEM_DESIGN_LEARNING.md). Dynamic financial planning is phase two. The first milestone is a local finance app with a browser demo; online sign-in, banking/broker integrations, encrypted recovery and production backend delivery remain explicit next milestones. The existing web application below is preserved.

**A Modern Personal Finance Tracker**  
**Assignment Submission – Typeface AI Recruitment (Full Stack)**  
Developer: [Bhumil1312](https://github.com/Bhumil1312)

---

> **🚀 Monorepo notice:** This repo is being upgraded into a 10M-user microservices platform (Go backend on AWS + this Next.js app as the frontend). See [ARCHITECTURE.md](./ARCHITECTURE.md) for the target design and the Phase P0 scaffolding (protos, shared Go libs, auth-service, Terraform, CI). The instructions below still apply to the existing Next.js app.

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

- **Automated Email Alerts (80% Spending)**  
  Users get alerted when budget usage reaches 80%.

- **Bulk Transactions Import from PDF Statement**  
  Extract multiple transactions from uploaded PDF using LLM.

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
    - `DIRECT_URL` (optional)
    - `CLERK_SECRET_KEY`
    - `CLERK_PUBLISHABLE_KEY`
    - `GEMINI_API_KEY`
    - `ARCJET_KEY`
    - `RESEND_API_KEY`
    - `NEXT_PUBLIC_CLERK_FRONTEND_APIs` (optional)

4. Set up Prisma DB:
    ```
    npx prisma migrate dev
    npx prisma generate
    ```

---

## Development & Run Commands

You’ll need multiple terminals to run everything locally.

### 1. Run the main app
```
npm run dev
```

### 2. Run Inngest Dev Server (for email triggers & background jobs)
```
npx inngest-cli@latest dev
```

make sure your '/api/inngest' source is working

> ⚠️ If you don’t have `inngest-cli` installed:
> ```
> npm install -g inngest-cli
> ```

### 3. Run Email Testing Tool (like MailDev or any SMTP dev server)
```
npm run email
```

This enables you to test triggered emails (e.g., 80% budget warning).

---

## Git Workflow Instructions

To work on custom features or collaborate:

### Create & Switch to a Branch:
```
git checkout -b feature/my-new-feature
```
### Add, Commit & Push:
```
git add .
git commit -m "Added new income chart component"
git push -u origin feature/my-new-feature
```

Once pushed, collaborators and reviewers (including interviewers) can check your work in that branch.

---

## Assignment Deliverables

| Feature / Requirement                                  | Status             |
|--------------------------------------------------------|--------------------|
| Add/Edit income and expense entries                    | ✅ Implemented     |
| View entries by date range                             | ✅ Implemented     |
| Charts by category and over time                       | ✅ Implemented     |
| Upload POS receipts and extract data                   | ✅ Done (Gemini AI)|
| Upload & parse PDF (batch transactions)                | ✅ Done (Gemini AI)|
| APIs separate from frontend                            | ✅ Implemented     |
| Persistent PostgreSQL storage                          | ✅ With Prisma     |
| Auth for users and data isolation                      | ✅ With Clerk      |
| Paginated transactions                                 | ✅ Done            |
| Bonus: Email alerts at 85% budget                      | ✅ Implemented     |

---

## Limitations

- **Generative AI Output Variability**
  The structured transaction data extracted via Gemini AI from document images or other sources can sometimes be inconsistent or incomplete. Continual improvements are underway to enhance parsing accuracy and format consistency.

- **Edge Case Accuracy (OCR and Interpretation)**
  Receipts or statements with faded text, complex layouts, or unusual fonts may cause the AI to misinterpret details, leading to partial or incorrect transaction data.

- **Local Development Focus**
  This project is built assuming a local development environment. Additional configuration and optimization is needed for smooth deployment on production platforms like Vercel or Render.

---

## Demo

Watch a walkthrough of all features here:  
👉 [PennyWise Demo Playlist – YouTube](https://www.youtube.com/playlist?list=PLgToSABL-x9L29Ipv3QR3-c04SAjHhEhG)

---

## Contact

For questions, feedback, or demo requests, please [open an issue](https://github.com/Bhumil1312/PennyWise/issues) or contact [@Bhumil1312](https://github.com/Bhumil1312).

---
