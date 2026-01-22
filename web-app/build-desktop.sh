#!/bin/bash

# ThirdBooks Desktop App Build Script
# This script builds the desktop app for different platforms

set -e

echo "🏗️  ThirdBooks Desktop App Builder"
echo "=================================="
echo ""

# Check if in correct directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Must run from web-app directory"
    exit 1
fi

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "❌ Error: Rust not installed"
    echo "Install from: https://rustup.rs"
    exit 1
fi

# Check if Node.js is installed
if ! command -v npm &> /dev/null; then
    echo "❌ Error: Node.js/npm not installed"
    exit 1
fi

# Function to check icons
check_icons() {
    if [ ! -f "src-tauri/icons/icon.png" ]; then
        echo "⚠️  Warning: Icons not generated"
        echo ""
        echo "Quick fix:"
        echo "  npm install -g @tauri-apps/cli"
        echo "  curl -L https://raw.githubusercontent.com/tauri-apps/tauri/dev/tooling/cli/templates/app/app-icon.png -o src-tauri/icon-source.png"
        echo "  cd src-tauri && tauri icon icon-source.png && cd .."
        echo ""
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Install dependencies
install_deps() {
    echo "📦 Installing dependencies..."
    npm install
    echo "✅ Dependencies installed"
    echo ""
}

# Build for development
build_dev() {
    echo "🔨 Starting development build..."
    npm run tauri:dev
}

# Build for production
build_prod() {
    echo "🔨 Building for production..."

    check_icons

    echo "Building Tauri app..."
    npm run tauri:build

    echo ""
    echo "✅ Build complete!"
    echo ""
    echo "Output locations:"

    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "  📦 Windows:"
        echo "     - Portable: src-tauri/target/release/thirdbooks.exe"
        echo "     - Installer: src-tauri/target/release/bundle/msi/ThirdBooks_1.0.0_x64_en-US.msi"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  📦 macOS:"
        echo "     - DMG: src-tauri/target/release/bundle/dmg/ThirdBooks.dmg"
        echo "     - App: src-tauri/target/release/bundle/macos/ThirdBooks.app"
    else
        echo "  📦 Linux:"
        echo "     - AppImage: src-tauri/target/release/bundle/appimage/thirdbooks_1.0.0_amd64.AppImage"
        echo "     - DEB: src-tauri/target/release/bundle/deb/thirdbooks_1.0.0_amd64.deb"
    fi
}

# Show menu
show_menu() {
    echo "Select build type:"
    echo "  1) Development (with hot reload)"
    echo "  2) Production (optimized builds)"
    echo "  3) Install dependencies only"
    echo "  4) Check requirements"
    echo "  5) Exit"
    echo ""
    read -p "Choice [1-5]: " choice

    case $choice in
        1)
            install_deps
            build_dev
            ;;
        2)
            install_deps
            build_prod
            ;;
        3)
            install_deps
            ;;
        4)
            echo ""
            echo "System Requirements:"
            echo "==================="
            echo ""

            # Check Rust
            if command -v cargo &> /dev/null; then
                echo "✅ Rust: $(rustc --version)"
            else
                echo "❌ Rust: Not installed"
                echo "   Install: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            fi

            # Check Node
            if command -v node &> /dev/null; then
                echo "✅ Node.js: $(node --version)"
            else
                echo "❌ Node.js: Not installed"
            fi

            # Check npm
            if command -v npm &> /dev/null; then
                echo "✅ npm: $(npm --version)"
            else
                echo "❌ npm: Not installed"
            fi

            # Check platform-specific deps
            echo ""
            echo "Platform-specific dependencies:"
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                echo "  Run: sudo apt install libwebkit2gtk-4.0-dev build-essential curl wget libssl-dev libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev"
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                echo "  Run: xcode-select --install"
            elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
                echo "  Install: Microsoft Visual Studio C++ Build Tools"
                echo "  Install: WebView2 (usually pre-installed on Windows 10/11)"
            fi

            echo ""
            ;;
        5)
            echo "Goodbye! 👋"
            exit 0
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
}

# Main
main() {
    if [ $# -eq 0 ]; then
        show_menu
    else
        case "$1" in
            dev)
                install_deps
                build_dev
                ;;
            build|prod)
                install_deps
                build_prod
                ;;
            deps)
                install_deps
                ;;
            check)
                show_menu
                # Select option 4
                ;;
            *)
                echo "Usage: $0 [dev|build|deps|check]"
                echo ""
                echo "Options:"
                echo "  dev   - Start development build with hot reload"
                echo "  build - Create production build"
                echo "  deps  - Install dependencies only"
                echo "  check - Check system requirements"
                echo ""
                echo "Run without arguments for interactive menu"
                exit 1
                ;;
        esac
    fi
}

main "$@"
