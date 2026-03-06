# MAGIC BET LTD - Setup & Deployment Guide

**Complete guide to set up and run the MAGIC BET accounting system**

---

## 📋 **PRE-REQUISITES**

Before you begin, ensure you have:

- ✅ Flutter SDK installed (3.0 or higher)
- ✅ Dart SDK (comes with Flutter)
- ✅ Git installed
- ✅ Code editor (VS Code recommended)
- ✅ Windows/Linux/macOS desktop environment

---

## 🚀 **QUICK START (5 Minutes)**

### **Step 1: Clone & Setup**

```bash
# Navigate to the desktop app
cd THIRD-BOOKS/desktop

# Install dependencies
flutter pub get

# Generate database code
flutter pub run build_runner build --delete-conflicting-outputs
```

### **Step 2: Run the Application**

```bash
# Run on desktop
flutter run -d windows  # or linux, macos
```

### **Step 3: Login**

**Default Credentials:**
- Email: `marion@magicbet.ug`
- Password: (Set during first run)

---

## 📦 **COMPLETE SETUP PROCESS**

### **1. Database Setup**

The system uses Drift (SQLite) for local database storage.

**Database Location:**
- Windows: `C:\Users\[Username]\Documents\thirdbooks\thirdbooks.db`
- Linux: `~/Documents/thirdbooks/thirdbooks.db`
- macOS: `~/Documents/thirdbooks/thirdbooks.db`

**Schema Version:** 2 (includes MAGIC BET customizations)

### **2. Import Company Data**

After first login, run the Magic Bet setup:

```dart
// In your app, run once:
import 'package:thirdbooks/core/utils/magic_bet_setup.dart';

final db = AppDatabase();
await setupMagicBet(db);
```

This will:
- ✅ Create betting-specific Chart of Accounts
- ✅ Import 74 outlets from `outlet_data.json`
- ✅ Set default 40% commission rate
- ✅ Configure company profile

### **3. Verify Setup**

Check that the following are configured:

✅ **Navigation:**
- Outlets section in sidebar
- Revenue, Expenditures, Commissions links
- Assets & Depreciation links

✅ **Chart of Accounts:**
- 4000: Betting Machine Revenue
- 4010: Gaming Income
- 5000: Location Commission Expense (40%)
- 5100: Machine Maintenance & Repairs
- 5200: Outlet Operating Expenses
- 5300: Depreciation Expense
- 1500: Fixed Assets
- 1510: Accumulated Depreciation
- 2100: Commission Payable

✅ **Outlets:**
- 74 outlets loaded
- All with 40% commission rate
- Organized by regions: CENTRAL, NORTH, WEST, EAST, etc.

---

## 🎯 **DAILY OPERATIONS**

### **Recording Revenue**

1. **Navigate:** Outlets → Revenue
2. **Click:** "Record Revenue"
3. **Enter:**
   - Date
   - Total Amount (e.g., UGX 5,000,000)
   - Description (e.g., "Weekly revenue - Week 52")
   - Reference (optional)
4. **System Auto-Calculates:**
   - Commission (40%): UGX 2,000,000
   - Net to Company (60%): UGX 3,000,000
5. **Save:** Revenue recorded & commission payable created

### **Recording Expenditures**

1. **Navigate:** Outlets → Expenditures
2. **Click:** "Add Expense"
3. **Enter:**
   - Expense Type (Maintenance, Repairs, Supplies, etc.)
   - Amount
   - Description
   - Paid To (vendor/service provider)
   - Status (Pending/Approved/Paid)
4. **Save:** Expense recorded

### **Paying Commissions**

1. **Navigate:** Outlets → Commissions
2. **Click:** "Calculate Commissions"
3. **Select Period:** e.g., Jan 1 - Jan 31
4. **Review:** System shows 40% commission for each outlet
5. **Generate:** Payment vouchers created
6. **Process:** Pay location owners
7. **Mark as Paid:** Update status

### **Managing Assets**

1. **Navigate:** Assets → Assets
2. **Click:** "Add Asset"
3. **Enter:**
   - Asset Code (e.g., AST-001)
   - Category (Vehicle, Equipment, Furniture, etc.)
   - Name & Description
   - Purchase Price & Date
   - Supplier
   - Location/Outlet
4. **Setup Depreciation:**
   - Method: Declining Balance (percentage-based)
   - Rate: e.g., 20% per year
   - Period: Monthly or Yearly
   - Start Date
5. **Auto-Generate:** Depreciation entries created monthly/yearly

---

## 📊 **BUSINESS WORKFLOWS**

### **Monthly Closing Checklist**

- [ ] Record all outlet revenues
- [ ] Record all outlet expenditures
- [ ] Calculate monthly commissions
- [ ] Process commission payments
- [ ] Generate depreciation entries
- [ ] Review outlet performance reports
- [ ] Reconcile accounts

### **Sample Month-End Process**

```
1. Record Revenue: UGX 50,000,000 total from all outlets
   → Commission: UGX 20,000,000 (40%)
   → Net: UGX 30,000,000 (60%)

2. Record Expenditures: UGX 5,000,000
   → Maintenance: UGX 2,000,000
   → Repairs: UGX 1,500,000
   → Supplies: UGX 1,500,000

3. Calculate Commissions:
   → 74 outlets × average revenue
   → Generate payment vouchers
   → Total payable: UGX 20,000,000

4. Pay Commissions:
   → Bank transfers to location owners
   → Update status to "Paid"

5. Depreciation:
   → Auto-generate entries for all assets
   → Post to journal
   → Update asset book values

6. Reports:
   → Profit/Loss by Outlet
   → Commission Summary
   → Cash Flow Statement
```

---

## 🔧 **TROUBLESHOOTING**

### **Issue: Database not generated**

**Solution:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### **Issue: Outlets not showing**

**Solution:**
1. Check `outlet_data.json` exists in project root
2. Run Magic Bet setup script
3. Verify database tables created

### **Issue: Login fails**

**Solution:**
1. Check database exists
2. Verify user account created
3. Reset password via "Forgot Password"

### **Issue: Commission calculation wrong**

**Solution:**
1. Check outlet commission rate (should be 40%)
2. Verify revenue amount entered correctly
3. Review commission formula: Revenue × 40%

---

## 📱 **SUPPORT & CONTACTS**

**Admin User:** Marion
**Email:** marion@magicbet.ug
**Phone:** +256 788 160516
**Address:** Plot 45, Kampala Road, Kampala, Uganda

**Company Details:**
- **Name:** MAGIC BET LTD
- **TIN:** 1053396130
- **Registration:** UG-2024-123456
- **Website:** www.magicbet.ug

---

## 🎓 **TRAINING RESOURCES**

### **Video Tutorials** (Coming Soon)
- System Overview
- Recording Revenue
- Managing Commissions
- Asset Depreciation
- Monthly Closing

### **Documentation**
- `MAGIC_BET_IMPLEMENTATION.md` - Technical details
- `README.md` - General project info
- `INSTALLATION_GUIDE.md` - Deployment guide

---

## 🔒 **SECURITY & BACKUP**

### **Database Backup**

**Automatic:**
- Database file: `thirdbooks.db`
- Location: User Documents folder

**Manual Backup:**
```bash
# Windows
copy "%USERPROFILE%\Documents\thirdbooks\thirdbooks.db" backup_folder\

# Linux/Mac
cp ~/Documents/thirdbooks/thirdbooks.db ~/backup_folder/
```

**Recommended Schedule:**
- Daily: Auto-backup to cloud storage
- Weekly: Manual backup verification
- Monthly: Archive backup

### **User Access Control**

**Roles:**
1. **Admin** (Marion) - Full access
2. **Accountant** - Revenue, expenses, reports
3. **Cashier** - Revenue recording only
4. **Viewer** - Read-only reports

---

## 📈 **PERFORMANCE TIPS**

1. **Regular Cleanup:**
   - Archive old data quarterly
   - Optimize database monthly

2. **Efficient Data Entry:**
   - Use reference numbers for tracking
   - Batch import revenue when possible
   - Set up recurring expenses

3. **Report Generation:**
   - Generate reports during off-peak hours
   - Export to Excel for external analysis

---

## ✅ **POST-SETUP CHECKLIST**

After setup, verify:

- [ ] Login works with Marion's email
- [ ] MagicBet logo shows on login screen
- [ ] 74 outlets visible in Outlets screen
- [ ] Chart of Accounts has betting accounts
- [ ] Can record revenue with 40% commission
- [ ] Can add expenditures
- [ ] Commission calculation works
- [ ] Can add assets
- [ ] Depreciation calculator works
- [ ] All navigation links work
- [ ] Reports generate correctly

---

## 🎉 **READY TO GO!**

Your MAGIC BET accounting system is now configured and ready for production use.

**Start by:**
1. Recording your first revenue
2. Setting up sample expenditures
3. Calculating test commissions
4. Adding a sample asset

**Need help?** Contact marion@magicbet.ug

---

*Professional Betting & Gaming Accounting System*
*Powered by ThirdBooks - Customized for MAGIC BET LTD*
