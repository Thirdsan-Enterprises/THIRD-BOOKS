# ThirdBooks Desktop App Icons

## Required Icons

For the desktop app to build properly, you need these icon files:

- `32x32.png` - Small icon for taskbar
- `128x128.png` - Standard resolution icon
- `128x128@2x.png` - High DPI icon (256x256)
- `icon.icns` - macOS icon bundle
- `icon.ico` - Windows icon file
- `icon.png` - System tray icon (512x512)

## Quick Setup: Generate Icons Automatically

**Option 1: Using @tauri-apps/cli (Recommended)**

```bash
# Install Tauri CLI
npm install -g @tauri-apps/cli

# Generate all icons from a single source image (1024x1024 PNG)
tauri icon path/to/your-logo.png
```

This will automatically generate all required icon formats.

**Option 2: Manual Creation**

If you have a logo file, you can use online tools:

1. Go to https://icon.kitchen or https://www.favicon-generator.org/
2. Upload your logo (1024x1024 PNG recommended)
3. Download the icon pack
4. Copy the generated files to this directory

**Option 3: Use Placeholder (Development Only)**

For testing, you can use the default Tauri icons:

```bash
# This will download default icons
curl -L https://raw.githubusercontent.com/tauri-apps/tauri/dev/tooling/cli/templates/app/app-icon.png -o icon.png
npm install -g @tauri-apps/cli
tauri icon icon.png
```

## Icon Specifications

### Windows (.ico)
- Must contain multiple sizes: 16x16, 32x32, 48x48, 256x256
- RGB/RGBA format

### macOS (.icns)
- Must contain multiple sizes from 16x16 to 512x512
- RGB/RGBA format

### Linux (.png)
- Multiple sizes: 32x32, 128x128, 256x256, 512x512
- RGBA format

## Design Guidelines

- **Simple & Clear:** Icons should be recognizable at small sizes
- **Square Canvas:** Always use square dimensions (1:1 ratio)
- **Transparent Background:** Use PNG with alpha channel
- **High Contrast:** Ensure icon is visible on both light and dark backgrounds
- **Brand Colors:** Use ThirdBooks brand colors (blue theme)

## ThirdBooks Brand

**Suggested Icon Design:**
- Main color: Blue (#3B82F6)
- Accent: Dark Blue (#1E40AF)
- Symbol: "TB" monogram or book/ledger icon
- Style: Modern, clean, professional

## Testing Icons

After generating icons, test them:

```bash
# Build development version
npm run tauri dev

# Check system tray icon
# Check window icon
# Check taskbar icon
```

## Current Status

⚠️ **Icons not yet generated** - Please follow steps above to create icons before building.
