#!/bin/bash

# Fix Xcode Build Option Issues
# Behebt häufige Probleme, die dazu führen, dass die BUILD-Option in Xcode deaktiviert ist

set -e

echo "🔧 Fixing Xcode Build Issues..."
echo ""

# 1. Clean Derived Data
echo "1. Cleaning Derived Data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/FIN1-* 2>/dev/null || true
echo "✅ Derived Data cleaned"

# 2. Clean Build Folder
echo ""
echo "2. Cleaning build folder..."
xcodebuild -project FIN1.xcodeproj -scheme FIN1 clean 2>&1 | grep -E "(CLEAN|error)" || true
echo "✅ Build folder cleaned"

# 3. Verify project structure
echo ""
echo "3. Verifying project structure..."
if [ ! -f "Info.plist" ]; then
    echo "❌ Info.plist not found in project root"
    exit 1
fi
echo "✅ Info.plist found"

# 4. Verify project file
echo ""
echo "4. Verifying project file..."
if ! xcodebuild -project FIN1.xcodeproj -list > /dev/null 2>&1; then
    echo "❌ Project file is corrupted"
    exit 1
fi
echo "✅ Project file is valid"

# 5. Check schemes
echo ""
echo "5. Available schemes:"
xcodebuild -project FIN1.xcodeproj -list 2>&1 | grep -A 10 "Schemes:"

echo ""
echo "✅ Fix complete!"
echo ""
echo "💡 Next steps:"
echo "   1. Close Xcode completely (⌘Q)"
echo "   2. Reopen Xcode"
echo "   3. Open FIN1.xcodeproj"
echo "   4. Select Scheme: FIN1"
echo "   5. Select Destination: iOS Simulator"
echo "   6. Try building (⌘B)"
