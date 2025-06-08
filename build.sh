#!/bin/bash
# Build script for DoraCore KernelSU Selection Package
# Usage: ./build.sh

set -e

KERNEL_NAME="DoraCore-KernelSU-Selection"
VERSION="v1.0"
DATE=$(date +%Y%m%d)
OUTPUT_NAME="${KERNEL_NAME}-${VERSION}-${DATE}.zip"

echo "======================================"
echo "DoraCore KernelSU Selection Builder"
echo "======================================"
echo ""

# Check if required files exist
echo "🔍 Checking required files..."

if [ ! -f "anykernel.sh" ]; then
    echo "❌ anykernel.sh not found!"
    exit 1
fi

if [ ! -f "Image-kernelsu" ] || [ ! -f "Image-standard" ]; then
    echo "⚠️  Warning: Kernel image files not found!"
    echo "   Make sure to replace Image-kernelsu and Image-standard"
    echo "   with your actual kernel images before building."
    echo ""
fi

if [ ! -x "tools/keycheck" ]; then
    echo "⚠️  Warning: keycheck binary may not be executable"
    chmod +x tools/keycheck 2>/dev/null || true
fi

echo "✅ Basic file structure OK"
echo ""

# Create the ZIP package
echo "📦 Creating ZIP package..."
echo "   Output: $OUTPUT_NAME"

# Remove any previous build
rm -f "$OUTPUT_NAME" 2>/dev/null || true

# Create ZIP (excluding git and build files)
zip -r9 "$OUTPUT_NAME" . \
    -x "*.git*" \
    -x "build.sh" \
    -x "README.md" \
    -x "*.md" \
    -x ".DS_Store" \
    -x "*.log"

if [ $? -eq 0 ]; then
    echo "✅ ZIP package created successfully!"
    echo ""
    echo "📊 Package information:"
    echo "   File: $OUTPUT_NAME"
    echo "   Size: $(du -h "$OUTPUT_NAME" | cut -f1)"
    echo ""
    echo "🚀 Ready to flash!"
    echo ""
    echo "⚠️  Important reminders:"
    echo "   • Make sure Image-kernelsu contains your KernelSU kernel"
    echo "   • Make sure Image-standard contains your standard kernel"
    echo "   • Test on your device before distributing"
    echo "   • Always backup before flashing"
else
    echo "❌ Failed to create ZIP package!"
    exit 1
fi

echo ""
echo "======================================"
