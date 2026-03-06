# MagicBet Accounting System - User Manual

**Version:** 1.0.0
**Last Updated:** March 2026
**Company:** MAGIC BET LTD
**System:** ThirdBooks Professional Accounting

---

## Table of Contents

1. [Introduction](#introduction)
2. [System Overview](#system-overview)
3. [Getting Started](#getting-started)
4. [Dashboard](#dashboard)
5. [Outlet Management](#outlet-management)
6. [Revenue Tracking](#revenue-tracking)
7. [Expenditure Management](#expenditure-management)
8. [Commission Processing](#commission-processing)
9. [Asset Management](#asset-management)
10. [Depreciation Schedules](#depreciation-schedules)
11. [Financial Reports](#financial-reports)
12. [User Settings](#user-settings)
13. [Troubleshooting](#troubleshooting)
14. [Glossary](#glossary)

---

## 1. Introduction

Welcome to the MagicBet Accounting System! This comprehensive financial management platform is specifically designed for MAGIC BET LTD to efficiently manage:

- **74 betting machine outlets** across Uganda
- **Revenue collection** from all locations
- **Commission payments** to location owners (40% automatic calculation)
- **Outlet expenditures** and approvals
- **Company assets** and depreciation tracking
- **Complete financial reporting**

This manual will guide you through all features and operations of the system.

---

## 2. System Overview

### 2.1 Key Features

- ✅ **Outlet Management** - Track all 74 betting locations
- ✅ **Automated Commission** - 40% commission automatically calculated on revenue
- ✅ **Revenue Tracking** - Record and monitor income from each outlet
- ✅ **Expenditure Control** - Categorize and approve outlet expenses
- ✅ **Asset Management** - Track company assets (vehicles, equipment, furniture)
- ✅ **Depreciation** - Percentage-based asset depreciation schedules
- ✅ **Financial Reports** - Comprehensive accounting reports
- ✅ **Multi-user Access** - Role-based permissions
- ✅ **Offline Capability** - Work without internet connection

### 2.2 System Requirements

**Hardware:**
- Windows 10/11, macOS 10.15+, or Linux
- 4 GB RAM (8 GB recommended)
- 500 MB available disk space
- 1280x720 minimum screen resolution

**Software:**
- No additional software required
- Standalone desktop application

---

## 3. Getting Started

### 3.1 First-Time Login

**Step 1: Launch the Application**
- Double-click the **MagicBet Accounting** icon on your desktop
- The application will display the splash screen and initialize

**Step 2: Login with Marion's Account**

```
Email:    marion@magicbet.ug
Password: MagicBet@2026
```

**Step 3: Automatic Setup**
- On first login, the system automatically:
  - Imports all 74 betting outlets
  - Configures the Chart of Accounts
  - Sets 40% commission rate for all outlets
  - Creates company profile for MAGIC BET LTD

> **Note:** The first-time setup takes 10-15 seconds. Please wait for completion.

### 3.2 Alternative Login Methods

**Demo Mode (Testing Only):**
- Click **"View Demo"** on login screen
- No credentials required
- Full system access for testing

**Offline Mode:**
- If no internet connection is available
- Use the credentials above
- System works completely offline

---

## 4. Dashboard

### 4.1 Dashboard Overview

Upon login, you'll see the main dashboard displaying:

**Financial Summary Cards:**
- 📊 **Total Revenue** - All-time revenue from outlets
- 💰 **Commission Owed** - Total unpaid commissions
- 📤 **Pending Expenditures** - Awaiting approval
- 📈 **Net Income** - Revenue minus commissions and expenses

**Quick Stats:**
- Total number of outlets (74)
- Active outlets
- This month's revenue
- Outstanding balances

**Recent Activities:**
- Latest revenue entries
- Recent expenditure requests
- Recent commission payments
- Pending approvals

### 4.2 Navigation Sidebar

The left sidebar provides access to all system features:

**MAIN**
- 🏠 Dashboard - Main overview screen

**ACCOUNTING**
- 🌳 Chart of Accounts - Account structure
- 📖 Journal Entries - Manual accounting entries

**SALES**
- 👥 Customers - Customer records
- 🧾 Invoices - Sales invoices

**PURCHASES**
- 🏪 Vendors - Vendor/supplier records
- 📄 Bills - Purchase bills

**BANKING**
- 💳 Payments - Payment processing

**OUTLETS** (MagicBet Specific)
- 🏢 **Outlets** - Manage 74 locations
- 💵 **Revenue** - Record outlet revenue
- 💸 **Expenditures** - Track outlet expenses
- 🎁 **Commissions** - Manage 40% commission payments

**ASSETS**
- 📦 **Assets** - Company asset registry
- 📉 **Depreciation** - Asset depreciation schedules

**REPORTS**
- 📊 Reports - Financial statements and analysis

---

## 5. Outlet Management

### 5.1 Viewing Outlets

**Navigation:** Sidebar → OUTLETS → **Outlets**

**Outlet List Shows:**
- Outlet Code (e.g., 3000, 3001)
- Outlet Name (e.g., MAGIC BET YUMBE)
- Location (City/Town)
- Region (CENTRAL, NORTH, WEST, EAST, WEST NILE, SOUTH WEST)
- Commission Rate (40%)
- Status (Active/Inactive)

**Statistics Dashboard:**
- 🏪 Total Outlets: 74
- ✅ Active: 74
- 💰 This Month Revenue: UGX X,XXX,XXX
- 🎁 Pending Commissions: UGX X,XXX,XXX

### 5.2 Searching and Filtering

**Search Box:**
- Type outlet name, code, or location
- Results update in real-time

**Region Filter:**
- Select from dropdown:
  - All (default)
  - CENTRAL
  - NORTH
  - WEST
  - EAST
  - WEST NILE
  - SOUTH WEST

### 5.3 Adding a New Outlet

> **Note:** The 74 existing outlets are already imported. Use this only for new locations.

**Steps:**
1. Click **"+ Add Outlet"** button (top right)
2. Fill in the form:
   - **Outlet Code*** (e.g., 3074)
   - **Outlet Name*** (e.g., MAGIC BET KAMPALA NORTH)
   - **Address** (Street address)
   - **City** (City/Town name)
   - **Region** (Select from dropdown)
   - **Owner Name** (Location owner)
   - **Contact** (Phone number)
   - **Commission Rate (%)** (Default: 40%)
3. Click **"Add Outlet"**

**Validation:**
- Outlet Code must be unique
- Commission rate must be 0-100%
- Required fields marked with *

### 5.4 Viewing Outlet Details

Click on any outlet row to view:
- Complete outlet information
- Revenue history
- Expenditure history
- Commission payment history
- Outstanding balances

---

## 6. Revenue Tracking

### 6.1 Recording Revenue

**Navigation:** Sidebar → OUTLETS → **Revenue**

**Purpose:** Record revenue collected from betting machines at each outlet.

**Steps to Record Revenue:**

1. Click **"+ Record Revenue"** button
2. Complete the form:

   **Basic Information:**
   - **Outlet** (Select from dropdown - all 74 outlets)
   - **Collection Date** (Date revenue was collected)
   - **Amount (UGX)** (Gross revenue amount)

   **Commission (Auto-Calculated):**
   - System automatically calculates **40% commission**
   - Example: Revenue UGX 1,000,000 → Commission UGX 400,000
   - Commission is what you owe to the location owner

   **Payment Details:**
   - **Payment Method** (Cash, Bank Transfer, Mobile Money)
   - **Reference Number** (Receipt/transaction number)
   - **Notes** (Optional - any additional information)

3. Review the auto-calculated commission
4. Click **"Record Revenue"**

### 6.2 Commission Calculation Example

```
Outlet: MAGIC BET YUMBE (Code: 3000)
Collection Date: March 5, 2026
Gross Revenue: UGX 2,500,000

Auto-Calculated:
├─ Commission (40%): UGX 1,000,000 (Owed to location owner)
├─ Net Revenue (60%): UGX 1,500,000 (Company keeps)
└─ Commission Status: UNPAID
```

### 6.3 Revenue History

**View Options:**
- All revenues (default)
- Filter by outlet
- Filter by date range
- Filter by status (Paid/Unpaid commission)

**Export:**
- Click **Download** icon
- Export to Excel/PDF for reporting

**Revenue List Shows:**
- Collection Date
- Outlet Name
- Gross Revenue
- Commission Amount (40%)
- Net Revenue (60%)
- Payment Method
- Reference Number
- Commission Status

---

## 7. Expenditure Management

### 7.1 Recording Expenditures

**Navigation:** Sidebar → OUTLETS → **Expenditures**

**Purpose:** Track expenses incurred at each outlet (maintenance, repairs, supplies, etc.)

**Expenditure Categories:**
1. **Maintenance** - Regular upkeep and servicing
2. **Repairs** - Fixing broken equipment
3. **Supplies** - Consumables (paper, ink, etc.)
4. **Utilities** - Electricity, water bills
5. **Security** - Security services/equipment
6. **Rent** - Monthly rent payments
7. **Transportation** - Travel/delivery costs
8. **Other** - Miscellaneous expenses

### 7.2 Adding an Expenditure

**Steps:**
1. Click **"+ Add Expenditure"** button
2. Fill in the form:

   **Details:**
   - **Outlet** (Select outlet)
   - **Category** (Select from 8 categories)
   - **Expense Date** (Date expense occurred)
   - **Amount (UGX)** (Expense amount)
   - **Description** (What the expense was for)
   - **Vendor/Payee** (Who was paid)

   **Supporting Documents:**
   - **Receipt Number** (If applicable)
   - **Attach Receipt** (Upload photo/PDF of receipt)

3. Click **"Submit for Approval"**

### 7.3 Approval Workflow

**Status Flow:**
```
PENDING → APPROVED → PAID
   ↓
REJECTED
```

**Status Meanings:**
- **PENDING** - Awaiting manager approval
- **APPROVED** - Approved, awaiting payment
- **PAID** - Payment completed
- **REJECTED** - Expenditure rejected (with reason)

**Approving Expenditures:**
(Admin/Manager role required)
1. Review pending expenditures
2. Check supporting documents
3. Click **"Approve"** or **"Reject"**
4. If rejecting, provide reason

### 7.4 Viewing Expenditure Reports

**Filters Available:**
- By outlet
- By category
- By status
- By date range

**Summary Statistics:**
- Total expenditures this month
- By category breakdown
- Pending approval amount
- Approved but unpaid amount

---

## 8. Commission Processing

### 8.1 Commission Overview

**Navigation:** Sidebar → OUTLETS → **Commissions**

**What is Commission?**
- Location owners receive **40% of gross revenue**
- Automatically calculated when revenue is recorded
- Tracked as "Commission Owed" until paid

### 8.2 Viewing Commissions

**Dashboard Shows:**
- 💰 **Total Unpaid Commissions** - All outstanding amounts
- 📅 **This Month Commissions** - Current month total
- 👥 **Number of Outlets** - With pending payments
- 📊 **Average Commission** - Per outlet

**Commission List:**
- Outlet Name
- Owner Name
- Period (Month/Year)
- Total Revenue (for period)
- Commission Amount (40%)
- Payment Status
- Actions

### 8.3 Generating Commission Report

**Steps:**
1. Click **"Calculate Commissions"** button
2. Select parameters:
   - **Period Start Date**
   - **Period End Date**
   - **Outlets** (Select specific or "All")
3. Click **"Generate Report"**

**Report Shows:**
```
MAGIC BET YUMBE (3000)
Owner: John Doe
Phone: +256 700 123456

Period: March 1-31, 2026
Revenue Entries:
├─ Mar 5:  UGX 2,500,000 → Commission: UGX 1,000,000
├─ Mar 12: UGX 1,800,000 → Commission: UGX 720,000
└─ Mar 25: UGX 2,200,000 → Commission: UGX 880,000

Total Revenue:     UGX 6,500,000
Total Commission:  UGX 2,600,000 (40%)
Status: UNPAID
```

### 8.4 Processing Commission Payments

**Single Payment:**
1. Click **"Pay"** button on commission row
2. Enter payment details:
   - **Payment Date**
   - **Payment Method** (Cash, Bank, Mobile Money)
   - **Reference Number** (Transaction ID)
   - **Notes** (Optional)
3. Click **"Record Payment"**
4. Status changes to **PAID**

**Bulk Payment:**
1. Select multiple commissions (checkboxes)
2. Click **"Process Bulk Payments"**
3. Enter common payment details
4. Confirm payment
5. System creates payment vouchers for all

### 8.5 Commission Payment Voucher

After payment, system generates voucher with:
- Voucher Number (unique)
- Outlet Details
- Owner Information
- Period Covered
- Revenue Breakdown
- Commission Calculation
- Payment Details
- Authorized Signature Line

**Print/Export:**
- Click **"Print Voucher"**
- Save as PDF
- Email to owner (if email available)

---

## 9. Asset Management

### 9.1 What are Assets?

**Navigation:** Sidebar → ASSETS → **Assets**

**Important:** This is for **company assets** only, NOT betting machines.

**Asset Categories:**
- 🚗 **Vehicles** - Company cars, motorcycles
- 🖥️ **Equipment** - Office equipment, computers
- 🪑 **Furniture** - Desks, chairs, cabinets
- 📱 **Electronics** - Phones, tablets, printers
- 🏗️ **Other** - Any other company assets

**Example Assets:**
- Toyota Hiace (Company vehicle)
- HP Laptop (Office equipment)
- Office desk and chairs
- Air conditioner
- Security cameras

### 9.2 Adding an Asset

**Steps:**
1. Click **"+ Add Asset"** button
2. Fill in asset information:

   **Basic Details:**
   - **Asset Name** (e.g., "Toyota Hiace - UBB 123A")
   - **Category** (Select from dropdown)
   - **Asset Code** (Optional internal code)

   **Financial Information:**
   - **Purchase Date** (Date acquired)
   - **Purchase Cost (UGX)** (Original cost)
   - **Supplier** (Where purchased from)

   **Depreciation:**
   - **Depreciation Method** (Percentage-based)
   - **Depreciation Rate (%)** (e.g., 20% per year)
   - **Depreciation Period** (Monthly or Yearly)

   **Assignment:**
   - **Location/Outlet** (Where asset is located)
   - **Custodian** (Person responsible)

   **Additional:**
   - **Description** (Full details)
   - **Serial Number** (If applicable)
   - **Warranty Expiry** (Date)
   - **Photos** (Upload asset photos)

3. Click **"Add Asset"**

### 9.3 Asset Depreciation Example

```
Asset: Toyota Hiace - UBB 123A
Category: Vehicle
Purchase Date: January 1, 2024
Purchase Cost: UGX 85,000,000
Depreciation Rate: 20% per year

Depreciation Schedule:
Year 1 (2024):
├─ Opening Value:    UGX 85,000,000
├─ Depreciation:     UGX 17,000,000 (20%)
└─ Closing Value:    UGX 68,000,000

Year 2 (2025):
├─ Opening Value:    UGX 68,000,000
├─ Depreciation:     UGX 13,600,000 (20% of 68M)
└─ Closing Value:    UGX 54,400,000

Year 3 (2026):
├─ Opening Value:    UGX 54,400,000
├─ Depreciation:     UGX 10,880,000 (20% of 54.4M)
└─ Current Value:    UGX 43,520,000
```

### 9.4 Managing Assets

**Asset List View:**
- Asset Name & Code
- Category
- Purchase Cost
- Current Value (after depreciation)
- Depreciation Rate
- Location/Outlet
- Status (Active/Disposed)
- Actions

**Available Actions:**
- 👁️ **View Details** - Complete asset information
- ✏️ **Edit** - Update asset details
- 📉 **Depreciation Schedule** - View/edit depreciation
- 🔄 **Transfer** - Move to different outlet
- 🗑️ **Dispose** - Mark as sold/scrapped

**Filters:**
- By category
- By location
- By status
- By value range

### 9.5 Asset Disposal

When selling or scrapping an asset:
1. Click **"Dispose"** on asset
2. Enter disposal details:
   - **Disposal Date**
   - **Disposal Method** (Sale/Scrap/Donation)
   - **Sale Amount** (If sold)
   - **Buyer Details** (If sold)
   - **Reason**
3. System calculates:
   - Book Value (depreciated value)
   - Sale Amount
   - Profit/Loss on disposal
4. Creates disposal journal entry

---

## 10. Depreciation Schedules

### 10.1 Understanding Depreciation

**Navigation:** Sidebar → ASSETS → **Depreciation**

**What is Depreciation?**
- Reduction in asset value over time
- Percentage-based (Declining Balance method)
- Can be monthly or yearly

**Why Track Depreciation?**
- Accurate asset valuation
- Tax compliance
- Financial reporting
- Cost allocation

### 10.2 Depreciation Calculator

**Access:**
- Click **"Depreciation Calculator"** (calculator icon)

**Calculate Future Value:**
1. Enter:
   - Original Cost
   - Depreciation Rate (%)
   - Time Period (years/months)
2. Click **"Calculate"**
3. See depreciated value

**Example:**
```
Original Cost: UGX 10,000,000
Rate: 15% per year
Period: 3 years

Year 1: 10,000,000 - (15%) = 8,500,000
Year 2: 8,500,000 - (15%)  = 7,225,000
Year 3: 7,225,000 - (15%)  = 6,141,250

Current Value: UGX 6,141,250
Total Depreciation: UGX 3,858,750
```

### 10.3 Viewing Depreciation Schedules

**Dashboard Shows:**
- 📉 **Total Depreciation This Year**
- 📊 **Number of Depreciable Assets**
- 💰 **Current Asset Value** (All assets combined)
- 📅 **Next Scheduled Depreciation**

**Schedule List:**
- Asset Name
- Category
- Original Cost
- Accumulated Depreciation
- Current Book Value
- Depreciation Rate
- Last Depreciation Date
- Next Due Date

### 10.4 Generating Depreciation Entries

**Manual Generation:**
1. Click **"Generate Entries"** button
2. Select period:
   - **Month** (for monthly depreciation)
   - **Year** (for yearly depreciation)
3. Review assets to be depreciated
4. Click **"Generate"**
5. System creates journal entries:
   ```
   Dr. Depreciation Expense    UGX XXX
       Cr. Accumulated Depreciation    UGX XXX
   ```

**Automatic Generation:**
- Set up automatic monthly/yearly depreciation
- System runs automatically on schedule
- Email notifications sent
- Review and approve entries

### 10.5 Depreciation Reports

**Available Reports:**
- Asset Register (with current values)
- Depreciation Schedule (future projections)
- Depreciation Expense Summary
- Asset Category Analysis
- Location-wise Asset Report

**Export Options:**
- Excel (for analysis)
- PDF (for printing)
- CSV (for other systems)

---

## 11. Financial Reports

### 11.1 Available Reports

**Navigation:** Sidebar → REPORTS → **Reports**

**MagicBet Specific Reports:**

**Outlet Reports:**
1. **Outlet Revenue Summary**
   - Revenue by outlet
   - Revenue by region
   - Monthly trends
   - Year-over-year comparison

2. **Commission Report**
   - Total commissions by outlet
   - Paid vs unpaid commissions
   - Commission aging report
   - Owner payment history

3. **Outlet Expenditure Analysis**
   - Expenditure by outlet
   - Expenditure by category
   - Approval status summary
   - Variance analysis

4. **Outlet Profitability**
   - Revenue minus commissions
   - Revenue minus all costs
   - Net income by outlet
   - Most/least profitable outlets

**Standard Accounting Reports:**
1. **Profit & Loss Statement**
   - Revenue
   - Less: Commission expense
   - Less: Operating expenses
   - Net Income

2. **Balance Sheet**
   - Assets (including betting machines at current value)
   - Liabilities (including unpaid commissions)
   - Equity

3. **Cash Flow Statement**
   - Operating activities
   - Investing activities
   - Financing activities

4. **Trial Balance**
   - All account balances
   - Debit and credit totals

**Asset Reports:**
1. **Asset Register** - All company assets
2. **Depreciation Schedule** - Future depreciation
3. **Asset Valuation** - Current asset values
4. **Disposal Register** - Sold/scrapped assets

### 11.2 Generating Reports

**Steps:**
1. Navigate to **Reports** section
2. Select report type from list
3. Set parameters:
   - **Date Range** (From - To)
   - **Outlets** (Specific or All)
   - **Categories** (If applicable)
   - **Status Filters** (If applicable)
4. Click **"Generate Report"**

**Report Options:**
- 👁️ **Preview** - View on screen
- 📄 **Print** - Print to printer
- 💾 **Export PDF** - Save as PDF
- 📊 **Export Excel** - Download as Excel
- 📧 **Email** - Send to recipients

### 11.3 Custom Report Parameters

**Outlet Revenue Report Example:**
- **Period:** March 1-31, 2026
- **Regions:** CENTRAL, NORTH
- **Sort By:** Revenue (Highest first)
- **Include:** Commission calculations
- **Show:** Top 10 outlets

**Commission Report Example:**
- **Period:** January-March 2026
- **Status:** UNPAID only
- **Outlets:** All
- **Group By:** Region
- **Show:** Owner contact details

---

## 12. User Settings

### 12.1 Profile Settings

**Access:** Sidebar → **Settings** → Profile

**Update:**
- Name
- Email
- Phone Number
- Password (change)

**Steps to Change Password:**
1. Enter **Current Password**
2. Enter **New Password** (min 8 characters)
3. **Confirm New Password**
4. Click **"Update Password"**

### 12.2 System Preferences

**Date & Number Format:**
- Date format (DD/MM/YYYY or MM/DD/YYYY)
- Currency (UGX default)
- Number format (comma separator)

**Notifications:**
- Email notifications (on/off)
- Desktop notifications (on/off)
- Notification types:
  - New revenue entries
  - Pending approvals
  - Commission due reminders
  - Low balance alerts

**Backup & Sync:**
- Auto-backup frequency
- Backup location
- Cloud sync settings (if enabled)

---

## 13. Troubleshooting

### 13.1 Login Issues

**Problem: Can't remember password**
- **Solution:** Use the default password: `MagicBet@2026`
- If changed and forgotten, contact IT support

**Problem: "Invalid credentials" error**
- **Check:** Email is exactly `marion@magicbet.ug`
- **Check:** Password is case-sensitive
- **Try:** Click "View Demo" to test system

**Problem: Application won't start**
- **Check:** Windows version is 10 or 11
- **Try:** Restart computer
- **Try:** Reinstall application

### 13.2 Data Issues

**Problem: Outlets not showing (empty list)**
- **Check:** First-time setup completed
- **Solution:** Log out and log back in to trigger setup
- **Or:** Click "Add Outlet" and manually import

**Problem: Commission not calculating automatically**
- **Check:** Commission rate is set on outlet (should be 40%)
- **Check:** Revenue amount is correctly entered
- **Try:** Re-enter the revenue

**Problem: Can't find a specific outlet**
- **Use:** Search box (top of Outlets screen)
- **Use:** Region filter
- **Check:** Spelling of outlet name/code

### 13.3 Performance Issues

**Problem: Application running slow**
- **Check:** Available RAM (close other programs)
- **Try:** Restart application
- **Check:** Hard disk space (500 MB free minimum)

**Problem: Reports taking long to generate**
- **Reduce:** Date range (shorter period)
- **Reduce:** Number of outlets selected
- **Wait:** Large datasets take 30-60 seconds

### 13.4 Data Backup

**Automatic Backup:**
- System auto-backs up daily
- Backups stored in: `Documents\MagicBetBackups\`
- Keeps last 30 days

**Manual Backup:**
1. Settings → Backup & Restore
2. Click **"Backup Now"**
3. Choose save location
4. Wait for completion

**Restore from Backup:**
1. Settings → Backup & Restore
2. Click **"Restore"**
3. Select backup file (.backup extension)
4. Click **"Restore"**
5. **Warning:** Current data will be replaced

### 13.5 Common Error Messages

**"Database error occurred"**
- **Cause:** Data corruption
- **Solution:** Restore from backup

**"Network connection failed"**
- **Cause:** No internet (not required)
- **Solution:** Ignore - system works offline

**"Permission denied"**
- **Cause:** User role restrictions
- **Solution:** Contact admin for access

**"Invalid date range"**
- **Cause:** End date before start date
- **Solution:** Correct the dates

---

## 14. Glossary

**Term** | **Definition**
---------|---------------
**Outlet** | A location where betting machines are placed (74 total)
**Gross Revenue** | Total money collected from betting machines
**Commission** | 40% of gross revenue paid to location owner
**Net Revenue** | 60% of gross revenue retained by MAGIC BET (after commission)
**Expenditure** | Expenses incurred at outlets (maintenance, rent, etc.)
**Asset** | Company property (vehicles, equipment, NOT betting machines)
**Depreciation** | Reduction in asset value over time
**Book Value** | Current value of asset after depreciation
**Depreciable Asset** | Asset that loses value over time
**Disposal** | Selling or scrapping an asset
**Voucher** | Payment authorization document
**Journal Entry** | Accounting record of financial transaction
**Chart of Accounts** | List of all accounting accounts
**Debit (Dr)** | Left side of accounting entry (increases assets/expenses)
**Credit (Cr)** | Right side of accounting entry (increases liabilities/income)
**Accumulated Depreciation** | Total depreciation of an asset to date
**Declining Balance** | Depreciation method where % is applied to reducing balance

---

## Quick Reference Card

### **Default Login**
```
Email:    marion@magicbet.ug
Password: MagicBet@2026
```

### **Key Numbers**
- **Total Outlets:** 74
- **Commission Rate:** 40%
- **Net Revenue Rate:** 60%

### **Expense Categories (8)**
1. Maintenance
2. Repairs
3. Supplies
4. Utilities
5. Security
6. Rent
7. Transportation
8. Other

### **Asset Categories (5)**
1. Vehicles
2. Equipment
3. Furniture
4. Electronics
5. Other

### **Approval Statuses**
- PENDING → Awaiting approval
- APPROVED → Approved, not paid
- PAID → Completed
- REJECTED → Denied

### **Common Tasks**

**Record Revenue:**
OUTLETS → Revenue → + Record Revenue

**Add Expenditure:**
OUTLETS → Expenditures → + Add Expenditure

**Pay Commission:**
OUTLETS → Commissions → Pay button

**Add Asset:**
ASSETS → Assets → + Add Asset

**Generate Report:**
REPORTS → Reports → Select → Generate

---

## Support & Contact

**Technical Support:**
- Email: support@thirdbooks.digital
- Available: Monday-Friday, 8 AM - 6 PM

**System Administrator:**
- Marion
- Email: marion@magicbet.ug

**Training & Assistance:**
- In-person training available
- Video tutorials coming soon
- This manual (always accessible)

---

**© 2026 MAGIC BET LTD. All rights reserved.**
**Powered by ThirdBooks Professional Accounting**

*Manual Version 1.0.0 - March 2026*
