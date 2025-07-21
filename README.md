# PennyWise

**A Modern Personal Finance Tracker**  
**Assignment Submission – Typeface AI Recruitment (Full Stack)**  
Author: [Bhumil1312](https://github.com/Bhumil1312)

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Setup Instructions](#setup-instructions)
- [Folder Structure](#folder-structure)
- [Assignment Deliverables](#assignment-deliverables)
- [Limitations](#limitations)
- [Demo](#demo)
- [Contact](#contact)
- [License](#license)

---

## Overview

**PennyWise** is a full-featured personal finance web platform that allows users to manage multiple accounts, monitor spending, categorize financial activity, upload receipts, receive automated notifications, and perform AI-assisted document parsing.

This project was developed as part of the interview assignment for the Typeface AI hiring process and was designed to demonstrate proficiency in both full-stack development and product implementation.

---

## Features

### Core Functionality

- **Multi-Account Support**  
  Create and manage separate budgets and dashboards for multiple financial accounts.

- **Categorized Income & Expenses**  
  Add and edit categorized income/expense entries with full form validation.

- **Date-Filtered Transactions**  
  Filter and view transactions by date for detailed recordkeeping.

- **Persistent Data Storage**  
  Data is persisted in PostgreSQL via Prisma ORM.

- **Authenticated Multi-User Access**  
  Each user has secure access to their own account and transactions using Clerk.dev authentication.

---

### Advanced & Bonus Features

- **Receipt Upload with AI Parsing (Image)**  
  Upload POS receipts to automatically extract and prefill transaction details using Gemini AI.

- **Automated Email Alerts (at 85% Spend)**  
  Email notifications are sent when a user approaches 85% of their budget in any account.

- **Bulk Transaction Import from PDF (In Progress)**  
  Upload a full PDF bank statement and extract multiple transactions. The UI and Gemini API integration are implemented; parsing accuracy is currently being refined.

- **Visual Financial Analytics**  
  Dynamic charts show expenses by category and over time, per account.

- **Paginated Listing APIs**  
  All list views, such as transaction history, support pagination and filters.

---

## Technology Stack

| Layer         | Technology                                 |
|---------------|---------------------------------------------|
| Frontend      | Next.js (App Router), React, Tailwind CSS   |
| UI Components | Shadcn/UI, React Hook Form, Zod             |
| Backend       | Next.js API Routes                          |
| AI/OCR        | Google Gemini API (Vision and Text API)     |
| ORM/Database  | Prisma ORM, PostgreSQL                      |
| Authentication| Clerk.dev                                   |
| Emails        | Nodemailer (SMTP)                           |
| Deployment    | Local environment (configurable for cloud)  |

---

## Setup Instructions

### Prerequisites

- Node.js 18 or higher
- PostgreSQL database
- Gemini API Key (Google Generative AI)
- Clerk.dev project and keys
- SMTP credentials (for notification emails)

### Installation

1. Clone the repository:
    ```
    git clone https://github.com/Bhumil1312/PennyWise.git
    cd PennyWise
    ```

2. Install dependencies:
    ```
    npm install
    ```

3. Prepare environment config:
    ```
    cp .env.example .env.local
    ```

4. Set your environment variables:
    - `DATABASE_URL`
    - `CLERK_SECRET_KEY`
    - `CLERK_PUBLISHABLE_KEY`
    - `GEMINI_API_KEY`
    - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`

5. Run migrations:
    ```
    npx prisma migrate dev
    ```

6. Start development server:
    ```
    npm run dev
    ```

---

## Assignment Deliverables

### Implemented as per Typeface AI Project Specifications

| Requirement                                              | Status             |
|-----------------------------------------------------------|--------------------|
| Create/edit income and expense entries                    | ✅ Implemented     |
| List entries by time range                                | ✅ Implemented     |
| Display visual graphs by category and over time           | ✅ Implemented     |
| Extract transaction data from POS receipts                | ✅ Implemented (images) |
| Upload and parse PDF bank statement (bonus)               | ⚠️ In Progress     |
| Provide APIs separately from frontend                     | ✅ Done            |
| Persist data in database                                  | ✅ Prisma + PostgreSQL |
| Authentication and account isolation                      | ✅ Clerk integrated |
| Bonus: Automated email alerts at 85% spend per account    | ✅ Implemented     |
| Bonus: Paginated listing for transaction history          | ✅ Implemented     |

---

## Limitations

- **PDF Bank Statement Parsing (AI/LLM Accuracy)**  
  Currently, tabular statement PDFs are sent to Gemini pro-vision for parsing. While the UI, upload, and API routing are complete, Gemini's return format is sometimes inconsistent and causes JSON parsing issues. This feature is being actively refined and integrated.

- **OCR Limitations (Image Receipts)**  
  Poor-quality or stylized receipts may produce inconsistent or incomplete data from AI models.

- **Deployment-Ready Setup**  
  Configuration for production deployment (e.g., Vercel, Railway, Render) is not included but easily adjustable.

---

## Demo

Watch the full working demo and feature walkthrough  
👉 [PennyWise Demo Playlist – YouTube]((https://www.youtube.com/playlist?list=PLgToSABL-x9L29Ipv3QR3-c04SAjHhEhG))

---

## Contact

For questions, feedback, or demo requests, please [open an issue](https://github.com/Bhumil1312/PennyWise/issues) or contact [@Bhumil1312](https://github.com/Bhumil1312).

---
