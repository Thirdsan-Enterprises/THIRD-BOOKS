# GitHub Secrets Setup Guide for CI/CD

This guide shows you **exactly** how to add GitHub Secrets for automated deployment.

---

## 📍 Where to Add Secrets

1. Go to your repository: https://github.com/SAVIOUR26/THIRD-BOOKS
2. Click **Settings** (top menu)
3. In left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret** button
5. Add each secret below one by one

---

## 🔐 Required Secrets

### **Database Secrets** (From Neon.tech)

Your Neon.tech connection string:
```
postgresql://neondb_owner:npg_Aq64CRLuFsXl@ep-dry-truth-a8ni4cax-pooler.eastus2.azure.neon.tech/neondb?sslmode=require
```

Add these secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `DB_HOST` | `ep-dry-truth-a8ni4cax-pooler.eastus2.azure.neon.tech` | From connection string (after @) |
| `DB_DATABASE` | `neondb` | From connection string (after last /) |
| `DB_USERNAME` | `neondb_owner` | From connection string (before :) |
| `DB_PASSWORD` | `npg_Aq64CRLuFsXl` | From connection string (after : before @) |

---

### **DirectAdmin Secrets** (Your Hosting)

You need your DirectAdmin credentials:

| Secret Name | Value | How to Get | Example |
|-------------|-------|------------|---------|
| `DIRECTADMIN_HOST` | Your FTP hostname | DirectAdmin → FTP Accounts → Hostname | `ftp.thirdbooks.digital` |
| `DIRECTADMIN_USERNAME` | Your DirectAdmin username | From hosting provider email | `thirdbooks` or `your_username` |
| `DIRECTADMIN_PASSWORD` | Your DirectAdmin password | From hosting provider email | Your DA password |
| `DIRECTADMIN_PATH_API` | Backend directory path | Usually | `/public_html/api` |
| `DIRECTADMIN_PATH_WEB` | Frontend directory path | Usually | `/public_html` |

**To find your DirectAdmin username/password:**
- Check email from InterServer (or your host)
- Subject usually: "DirectAdmin Login Information"
- Or login to DirectAdmin and check File Manager for username

**To find FTP hostname:**
- DirectAdmin → FTP Accounts → Click "Manage FTP Accounts"
- Look for "FTP Server" or "Hostname"
- Usually: `ftp.yourdomain.com` or server IP

---

### **Laravel App Key** (For Backend)

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `APP_KEY` | 32-character key | Run locally: `cd backend && php artisan key:generate --show` |

**How to generate:**
```bash
cd backend
php artisan key:generate --show
# Copy the output (starts with base64:...)
```

**Example:** `base64:abcdefghijklmnopqrstuvwxyz123456789ABCDEFGHIJ=`

---

### **Email Configuration** (Optional - for notifications)

| Secret Name | Value | How to Get | Notes |
|-------------|-------|------------|-------|
| `MAIL_USERNAME` | Your Gmail address | Your email | e.g., `your-email@gmail.com` |
| `MAIL_PASSWORD` | App-specific password | Gmail → Security → App Passwords | **NOT your Gmail password!** |

**How to get Gmail App Password:**
1. Go to https://myaccount.google.com/security
2. Enable 2-Step Verification (if not enabled)
3. Search for "App passwords"
4. Generate password for "Mail" → "Other"
5. Copy the 16-character password (no spaces)

**Or skip email for now** - System will work without it (emails just won't send)

---

### **SSH Access** (Optional - for post-deployment commands)

Only if your DirectAdmin has SSH access:

| Secret Name | Value | How to Get | Default |
|-------------|-------|------------|---------|
| `SSH_ENABLED` | `true` or `false` | Set `true` if you have SSH | `false` (skip if no SSH) |
| `SSH_PORT` | Port number | Usually 22 or check with host | `22` |

**Most shared hosting doesn't have SSH** - That's OK! Workflow will skip SSH steps.

---

### **Desktop App Signing** (Optional - for auto-updates)

Only needed if you want auto-update feature:

| Secret Name | Value | How to Generate |
|-------------|-------|-----------------|
| `TAURI_PRIVATE_KEY` | Private key | `npm run tauri signer generate` |
| `TAURI_KEY_PASSWORD` | Key password | From above command |

**Skip for now** - You can add this later when setting up auto-updates.

---

### **Mobile App Signing** (Optional - for Play Store/App Store)

#### Android Signing:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `ANDROID_KEYSTORE_BASE64` | Base64 keystore | Generate keystore, then `base64 keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Store password | From keystore generation |
| `ANDROID_KEY_ALIAS` | Key alias | From keystore generation |
| `ANDROID_KEY_PASSWORD` | Key password | From keystore generation |

**How to generate Android keystore:**
```bash
keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias thirdbooks

# Then convert to base64
base64 keystore.jks | pbcopy  # macOS
base64 keystore.jks | xclip   # Linux
certutil -encode keystore.jks keystore.txt  # Windows, then copy text
```

**Skip for now** - Add when ready to publish to Play Store.

#### iOS Signing (Requires Apple Developer Account):

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `IOS_CERTIFICATE_BASE64` | Base64 certificate | Export .p12 from Xcode, then base64 |
| `IOS_CERTIFICATE_PASSWORD` | Cert password | Password when exporting .p12 |
| `IOS_PROVISION_BASE64` | Base64 provisioning profile | From Apple Developer portal |
| `IOS_KEYCHAIN_PASSWORD` | Temp password | Any password (for CI keychain) |

**Skip for now** - Requires $99/year Apple Developer account.

---

## ✅ Quick Checklist

### **Minimum Required Secrets (To Start):**

- [ ] `DB_HOST` - ✅ You have this (from Neon.tech)
- [ ] `DB_DATABASE` - ✅ You have this (neondb)
- [ ] `DB_USERNAME` - ✅ You have this (neondb_owner)
- [ ] `DB_PASSWORD` - ✅ You have this (npg_Aq64CRLuFsXl)
- [ ] `APP_KEY` - ⏳ Generate with `php artisan key:generate --show`
- [ ] `DIRECTADMIN_HOST` - ⏳ Get from DirectAdmin FTP settings
- [ ] `DIRECTADMIN_USERNAME` - ⏳ From hosting email
- [ ] `DIRECTADMIN_PASSWORD` - ⏳ From hosting email
- [ ] `DIRECTADMIN_PATH_API` - ✅ Use `/public_html/api`
- [ ] `DIRECTADMIN_PATH_WEB` - ✅ Use `/public_html`

### **Optional (Add Later):**
- [ ] `MAIL_USERNAME` - For email notifications
- [ ] `MAIL_PASSWORD` - Gmail app password
- [ ] `SSH_ENABLED` - If you have SSH access (set to `true`)
- [ ] `SSH_PORT` - If SSH enabled (usually `22`)

### **For Production Release (Add Much Later):**
- [ ] `TAURI_PRIVATE_KEY` - Desktop app auto-updates
- [ ] `TAURI_KEY_PASSWORD` - Desktop app signing
- [ ] `ANDROID_KEYSTORE_BASE64` - Play Store publishing
- [ ] `ANDROID_KEYSTORE_PASSWORD` - Android signing
- [ ] `IOS_CERTIFICATE_BASE64` - App Store publishing
- [ ] `IOS_CERTIFICATE_PASSWORD` - iOS signing

---

## 📝 Example: Adding a Secret

**Step-by-step for adding `DB_HOST`:**

1. Go to: https://github.com/SAVIOUR26/THIRD-BOOKS/settings/secrets/actions
2. Click **"New repository secret"** button
3. **Name:** `DB_HOST`
4. **Secret:** `ep-dry-truth-a8ni4cax-pooler.eastus2.azure.neon.tech`
5. Click **"Add secret"**
6. ✅ Done! Repeat for other secrets

---

## 🔍 How to Find DirectAdmin Info

### **Method 1: Check Hosting Email**

Search your email for:
- Subject: "DirectAdmin Login"
- Subject: "Welcome to InterServer"
- Subject: "Account Information"

Look for:
- **Control Panel URL:** https://server123.interserver.com:2222
- **Username:** thirdbooks or similar
- **Password:** Your DA password
- **FTP Server:** ftp.thirdbooks.digital

### **Method 2: Login to DirectAdmin**

1. Login at: https://your-server.com:2222
2. Click **"FTP Accounts"** or **"FTP Management"**
3. Look for:
   - **FTP Server/Hostname:** This is your `DIRECTADMIN_HOST`
   - **Username:** This is your `DIRECTADMIN_USERNAME`

### **Method 3: Ask Your Host**

Contact InterServer support and ask:
- "What is my FTP hostname for thirdbooks.digital?"
- "What is my DirectAdmin username?"
- "Do I have SSH access?" (probably no)

---

## 🧪 Test After Adding Secrets

After adding minimum required secrets, test workflows:

### **Test 1: Backend Deployment**
```bash
# Make small change to backend
cd backend
echo "# Test deployment" >> README.md
git add .
git commit -m "test: Backend deployment via CI/CD"
git push origin main
```

Go to: https://github.com/SAVIOUR26/THIRD-BOOKS/actions
Watch the **"Deploy Backend to DirectAdmin"** workflow run.

### **Test 2: Frontend Deployment**
```bash
# Make small change to frontend
cd web-app
echo "// Test" >> src/main.ts
git add .
git commit -m "test: Frontend deployment via CI/CD"
git push origin main
```

Watch the **"Deploy Frontend to DirectAdmin"** workflow run.

### **Test 3: Desktop App Build**
```bash
# Create release tag
git tag v1.0.0
git push origin v1.0.0
```

Watch the **"Build Desktop App"** workflow build installers for Windows/Mac/Linux.

---

## ❓ Troubleshooting

### **"Secret not found" error**

**Problem:** Workflow fails with "secret is required but not provided"

**Solution:**
1. Check secret name spelling (case-sensitive!)
2. Verify secret is added to repository (not organization)
3. Secret names must match exactly (e.g., `DB_HOST` not `db_host`)

### **FTP connection failed**

**Problem:** "Failed to connect to FTP server"

**Solution:**
1. Verify `DIRECTADMIN_HOST` is correct (try in FTP client like FileZilla)
2. Check `DIRECTADMIN_USERNAME` and `DIRECTADMIN_PASSWORD`
3. Some hosts use IP address instead of hostname
4. Try with/without `ftp.` prefix

### **Database connection failed**

**Problem:** "SQLSTATE[08006] could not connect to server"

**Solution:**
1. Verify all DB_* secrets are correct
2. Check Neon.tech database is active (login to dashboard)
3. Ensure connection string has `?sslmode=require`

### **Permission denied (during deployment)**

**Problem:** "Permission denied: storage/"

**Solution:**
1. After first deployment, manually set permissions in DirectAdmin:
   - File Manager → navigate to `api/storage/`
   - Select folder → Permissions → `775`
   - Do same for `api/bootstrap/cache/`
2. Or enable SSH and workflow will handle it

---

## 🎯 Next Steps

After adding secrets:

1. ✅ Commit and push workflow files (I'll do this)
2. ✅ Test backend deployment (push a change)
3. ✅ Test frontend deployment (push a change)
4. ✅ Create release tag to test desktop builds
5. ✅ Access deployed site at https://thirdbooks.digital
6. ✅ Login as super admin
7. ✅ Download and test desktop installer

---

## 📞 Need Help?

**Finding DirectAdmin credentials?**
- Check email from InterServer
- Or contact InterServer support: https://interserver.net/support

**Issues with secrets?**
- GitHub Docs: https://docs.github.com/en/actions/security-guides/encrypted-secrets
- Or let me know which secret is causing issues

---

**Last Updated:** January 22, 2026
**Status:** Ready for Setup ✅
