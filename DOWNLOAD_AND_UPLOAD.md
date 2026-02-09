# 📦 ThirdBooks - Manual Upload Files Checklist

## ✅ Everything is Ready for Manual Upload!

All files have been prepared for you to manually upload to DirectAdmin.

---

## 📥 **Files to Download from This Repository**

### 1. **Backend API** (Entire `backend/` folder)
**Location:** `/home/user/THIRD-BOOKS/backend/`
**Upload To:** `/domains/api.thirdbooks.digital/public_html/`

**What you need:**
```
backend/
├── app/                    ✅ Upload
├── bootstrap/              ✅ Upload
├── config/                 ✅ Upload
├── database/               ✅ Upload
├── public/                 ✅ Upload (contents go to root!)
├── resources/              ✅ Upload
├── routes/                 ✅ Upload
├── storage/                ✅ Upload
├── artisan                 ✅ Upload
├── composer.json           ✅ Upload
├── composer.lock           ✅ Upload
└── .env.production         ✅ Copy & rename to .env
```

**DO NOT upload:**
- `.git/` folder
- `node_modules/` folder
- `tests/` folder
- `.env` file (create new from .env.production)

---

### 2. **Landing Page** (`landing-page/` folder)
**Location:** `/home/user/THIRD-BOOKS/landing-page/`
**Upload To:** `/domains/thirdbooks.digital/public_html/`

**Files:**
```
landing-page/
├── index.html             ✅ Upload (must be in root!)
├── css/
│   └── style.css          ✅ Upload
├── js/
│   └── main.js            ✅ Upload
└── images/
    └── favicon.svg        ✅ Upload
```

**Expected result on server:**
```
/domains/thirdbooks.digital/public_html/
├── index.html  ← Landing page will load from here
├── css/
├── js/
└── images/
```

---

### 3. **Database SQL File**
**Location:** `/home/user/THIRD-BOOKS/database-export.sql`
**Import Via:** DirectAdmin → MySQL Management → phpMyAdmin

**File:** `database-export.sql` (Contains complete schema + initial data)

---

## 🚀 **Quick Upload Guide**

### Step 1: Download Files from Repository

If you're using Git:
```bash
# Clone or pull latest
git pull origin main

# Files are in:
# - backend/
# - landing-page/
# - database-export.sql
# - MANUAL_DEPLOYMENT.md (instructions)
```

Or download ZIP from GitHub and extract.

---

### Step 2: Prepare Backend for Upload

1. **Copy .env.production to .env**
   ```bash
   cp backend/.env.production backend/.env
   ```

2. **Edit backend/.env** with your database credentials:
   ```env
   DB_DATABASE=thirdbooks_db
   DB_USERNAME=your_db_username
   DB_PASSWORD=your_db_password
   ```

3. **Generate APP_KEY** (on your local machine):
   ```bash
   cd backend
   php artisan key:generate --show
   # Copy the output (base64:xxxxx)
   # Paste into .env as APP_KEY value
   ```

---

### Step 3: Upload to DirectAdmin

#### **A. Upload Database First**

1. Login to DirectAdmin
2. Go to: **MySQL Management**
3. Create database: `thirdbooks_db`
4. Create user: `thirdbooks_user` with strong password
5. Assign user to database (All Privileges)
6. Open **phpMyAdmin**
7. Select `thirdbooks_db`
8. Click **Import** tab
9. Choose file: `database-export.sql`
10. Click **Go**
11. Wait for "Import has been successfully finished"

#### **B. Upload Backend Files**

**Via FTP (Recommended for large uploads):**

1. Connect to FTP using your DirectAdmin credentials
2. Navigate to: `/domains/api.thirdbooks.digital/public_html/`
3. Delete any default files (index.html, etc.)
4. Upload ALL files from `backend/` folder
5. Make sure `.env` file is uploaded with your credentials

**Via DirectAdmin File Manager:**

1. Go to: **File Manager**
2. Navigate to: `/domains/api.thirdbooks.digital/public_html/`
3. Click **Upload Files**
4. Upload all backend files (may take multiple uploads)

**CRITICAL:** Set folder permissions:
- `storage/` → 775
- `bootstrap/cache/` → 775

#### **C. Upload Landing Page**

1. Navigate to: `/domains/thirdbooks.digital/public_html/`
2. Delete any default files
3. Upload:
   - `index.html` (to root)
   - `css/` folder
   - `js/` folder
   - `images/` folder

---

### Step 4: Test Everything

1. **Test Landing Page:**
   - Visit: https://thirdbooks.digital
   - Expected: Beautiful landing page loads

2. **Test Backend API:**
   - Visit: https://api.thirdbooks.digital/api/health
   - Expected: JSON response with "status": "ok"

3. **Create Admin User** (via phpMyAdmin):
   - Go to `users` table
   - Click **Insert**
   - Fill:
     - name: Admin
     - email: admin@thirdbooks.digital
     - password: (use bcrypt generator online)
     - email_verified_at: Current timestamp
   - Click **Go**

4. **Test Desktop App:**
   - Open desktop app
   - Login with admin credentials
   - API URL: https://api.thirdbooks.digital
   - Create a customer
   - Verify sync works

---

## 📋 **Quick Checklist**

Before upload:
- [ ] Downloaded all files from repository
- [ ] Created `.env` from `.env.production`
- [ ] Generated APP_KEY
- [ ] Updated database credentials in `.env`

During upload:
- [ ] Created MySQL database `thirdbooks_db`
- [ ] Created database user with privileges
- [ ] Imported `database-export.sql` via phpMyAdmin
- [ ] Uploaded all backend files to `api.thirdbooks.digital/public_html/`
- [ ] Uploaded landing page to `thirdbooks.digital/public_html/`
- [ ] Set permissions on `storage/` and `bootstrap/cache/` to 775

After upload:
- [ ] Landing page loads at https://thirdbooks.digital
- [ ] API health check works at https://api.thirdbooks.digital/api/health
- [ ] Created admin user via phpMyAdmin
- [ ] Desktop app can login and sync

---

## 🆘 **Need Help?**

See `MANUAL_DEPLOYMENT.md` for detailed step-by-step instructions with screenshots and troubleshooting.

---

## 📂 **File Locations Summary**

| What | Where in Repo | Upload To |
|------|---------------|-----------|
| Backend | `/backend/` | `/domains/api.thirdbooks.digital/public_html/` |
| Landing Page | `/landing-page/` | `/domains/thirdbooks.digital/public_html/` |
| Database SQL | `/database-export.sql` | Import via phpMyAdmin |
| Instructions | `/MANUAL_DEPLOYMENT.md` | Read for detailed steps |

---

**Ready to deploy!** Follow the steps above and you'll have ThirdBooks running in 15-20 minutes! 🚀
