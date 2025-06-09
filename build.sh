#!/bin/bash

# DoraCore AnyKernel3 Build Script with KernelSU Selection
# Enhanced version with comprehensive validation and testing

set -e

# Configuration
KERNEL_NAME="DoraCore"
DEVELOPER="keosh"
VERSION="1.0"
BASE_NAME="DoraCore(keosh)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}$1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Main script
print_header "DoraCore AnyKernel3 Builder with KernelSU Selection"

print_info "Build Configuration:"
echo "   • Kernel: $KERNEL_NAME"
echo "   • Developer: $DEVELOPER"
echo "   • Version: $VERSION"
echo ""

# Check required files
print_info "Checking file structure..."

# Check core files
required_files=(
    "anykernel.sh"
    "META-INF/com/google/android/update-binary"
    "META-INF/com/google/android/updater-script"
    "tools/ak3-core.sh"
    "tools/busybox"
    "tools/keycheck"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found: $file"
    else
        print_error "Missing: $file"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    print_error "Missing required files. Cannot continue."
    exit 1
fi

# Check kernel images
print_info "Checking kernel images..."
has_kernelsu=false
has_standard=false

if [ -f "Image-kernelsu" ]; then
    print_success "Found KernelSU kernel: Image-kernelsu ($(du -h Image-kernelsu | cut -f1))"
    has_kernelsu=true
else
    print_warning "Missing KernelSU kernel: Image-kernelsu"
fi

if [ -f "Image-standard" ]; then
    print_success "Found standard kernel: Image-standard ($(du -h Image-standard | cut -f1))"
    has_standard=true
else
    print_warning "Missing standard kernel: Image-standard"
fi

if [ "$has_kernelsu" = false ] && [ "$has_standard" = false ]; then
    print_error "No kernel images found! You need at least one of:"
    echo "   • Image-kernelsu (for KernelSU support)"
    echo "   • Image-standard (for standard kernel)"
    exit 1
fi

# Validate kernel images
print_info "Validating kernel images..."
if [ "$has_kernelsu" = true ]; then
    ksu_size=$(stat --printf="%s" Image-kernelsu 2>/dev/null || echo "0")
    if [ "$ksu_size" -gt 1000000 ]; then
        print_success "KernelSU image size OK: $ksu_size bytes"
    else
        print_error "KernelSU image too small: $ksu_size bytes"
        exit 1
    fi
fi

if [ "$has_standard" = true ]; then
    std_size=$(stat --printf="%s" Image-standard 2>/dev/null || echo "0")
    if [ "$std_size" -gt 1000000 ]; then
        print_success "Standard image size OK: $std_size bytes"
    else
        print_error "Standard image too small: $std_size bytes"
        exit 1
    fi
fi

# Check keycheck binary
print_info "Checking keycheck binary..."
if [ -f "tools/keycheck" ]; then
    chmod +x tools/keycheck 2>/dev/null || true
    keycheck_size=$(stat --printf="%s" tools/keycheck 2>/dev/null || echo "0")
    if [ "$keycheck_size" -gt 1000 ]; then
        print_success "Keycheck binary OK: $keycheck_size bytes"
    else
        print_warning "Keycheck binary seems small: $keycheck_size bytes"
    fi
else
    print_error "Keycheck binary not found!"
    exit 1
fi

# Verify KernelSU selection functionality
print_info "Verifying KernelSU selection functionality..."
if grep -q "choose_kernelsu" META-INF/com/google/android/update-binary; then
    print_success "KernelSU selection function found in update-binary"
else
    print_error "KernelSU selection function missing in update-binary"
    exit 1
fi

if grep -q "KERNELSU_CHOICE" anykernel.sh; then
    print_success "KernelSU choice handling found in anykernel.sh"
else
    print_error "KernelSU choice handling missing in anykernel.sh"
    exit 1
fi

# Create build timestamp
BUILD_DATE=$(date +'%Y%m%d%H%M')
COMMIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")

# Determine build type and create appropriate ZIPs
print_header "Creating AnyKernel3 Package(s)"

if [ "$has_kernelsu" = true ] && [ "$has_standard" = true ]; then
    # Both kernels available - create selection ZIP
    ZIP_NAME="${BASE_NAME}-KernelSU-Selection-${BUILD_DATE}-${COMMIT_SHORT}.zip"
    print_info "Creating universal selection ZIP: $ZIP_NAME"
    
    # Remove old ZIP if exists
    rm -f "$ZIP_NAME" 2>/dev/null || true
    
    # Create ZIP with both kernel images
    zip -r9 "$ZIP_NAME" . \
        -x "*.git*" \
        -x "build.sh" \
        -x "build-enhanced.sh" \
        -x "*.md" \
        -x ".DS_Store" \
        -x "*.log"
    
    if [ $? -eq 0 ]; then
        print_success "Created selection ZIP: $ZIP_NAME"
        print_info "Package size: $(du -h "$ZIP_NAME" | cut -f1)"
        print_success "This ZIP allows users to choose KernelSU/Standard via volume keys"
    else
        print_error "Failed to create selection ZIP"
        exit 1
    fi
    
elif [ "$has_kernelsu" = true ]; then
    # Only KernelSU kernel available
    ZIP_NAME="${BASE_NAME}-KSU-only-${BUILD_DATE}-${COMMIT_SHORT}.zip"
    print_info "Creating KernelSU-only ZIP: $ZIP_NAME"
    
    # Copy KernelSU image as main image
    cp -f Image-kernelsu Image
    
    # Remove old ZIP if exists
    rm -f "$ZIP_NAME" 2>/dev/null || true
    
    # Create ZIP
    zip -r9 "$ZIP_NAME" . \
        -x "*.git*" \
        -x "build.sh" \
        -x "build-enhanced.sh" \
        -x "*.md" \
        -x ".DS_Store" \
        -x "*.log" \
        -x "Image-kernelsu" \
        -x "Image-standard"
    
    if [ $? -eq 0 ]; then
        print_success "Created KernelSU-only ZIP: $ZIP_NAME"
        print_info "Package size: $(du -h "$ZIP_NAME" | cut -f1)"
        print_warning "This ZIP only contains KernelSU kernel"
    else
        print_error "Failed to create KernelSU-only ZIP"
        exit 1
    fi
    
elif [ "$has_standard" = true ]; then
    # Only standard kernel available
    ZIP_NAME="${BASE_NAME}-Standard-only-${BUILD_DATE}-${COMMIT_SHORT}.zip"
    print_info "Creating standard-only ZIP: $ZIP_NAME"
    
    # Copy standard image as main image
    cp -f Image-standard Image
    
    # Remove old ZIP if exists
    rm -f "$ZIP_NAME" 2>/dev/null || true
    
    # Create ZIP
    zip -r9 "$ZIP_NAME" . \
        -x "*.git*" \
        -x "build.sh" \
        -x "build-enhanced.sh" \
        -x "*.md" \
        -x ".DS_Store" \
        -x "*.log" \
        -x "Image-kernelsu" \
        -x "Image-standard"
    
    if [ $? -eq 0 ]; then
        print_success "Created standard-only ZIP: $ZIP_NAME"
        print_info "Package size: $(du -h "$ZIP_NAME" | cut -f1)"
        print_warning "This ZIP only contains standard kernel"
    else
        print_error "Failed to create standard-only ZIP"
        exit 1
    fi
fi

# Final validation
print_header "Final Validation"

for zip_file in *.zip; do
    if [ -f "$zip_file" ]; then
        print_info "Validating: $zip_file"
        
        # Test ZIP integrity
        if unzip -t "$zip_file" >/dev/null 2>&1; then
            print_success "ZIP integrity check passed"
        else
            print_error "ZIP integrity check failed"
            exit 1
        fi
        
        # Check if selection ZIP contains required components
        if [[ "$zip_file" == *"Selection"* ]]; then
            if unzip -l "$zip_file" | grep -q "Image-kernelsu" && unzip -l "$zip_file" | grep -q "Image-standard"; then
                print_success "Selection ZIP contains both kernel images"
            else
                print_error "Selection ZIP missing kernel images"
                exit 1
            fi
        fi
        
        # Check for keycheck binary
        if unzip -l "$zip_file" | grep -q "tools/keycheck"; then
            print_success "Keycheck binary included"
        else
            print_warning "Keycheck binary not found in ZIP"
        fi
        
        # Check for core scripts
        if unzip -l "$zip_file" | grep -q "META-INF/com/google/android/update-binary"; then
            print_success "Update-binary included"
        else
            print_error "Update-binary missing"
            exit 1
        fi
        
        print_success "Validation completed for: $zip_file"
        echo ""
    fi
done

print_header "Build Summary"
print_success "All validations passed!"
echo ""
print_info "Generated packages:"
ls -la *.zip 2>/dev/null | grep -v "^d" | awk '{print "   • " $9 " (" $5 " bytes)"}'
echo ""
print_info "Package features:"
echo "   • Volume key selection (Vol+ = KernelSU, Vol- = Standard)"
echo "   • Enhanced keycheck implementation"
echo "   • Robust error handling"
echo "   • Debug information display"
echo "   • Multiple device support"
echo ""
print_success "Ready to flash! 🚀"
echo ""
print_warning "Important reminders:"
echo "   • Test in recovery before distributing"
echo "   • Make sure target device is supported"
echo "   • Users can choose KernelSU/Standard during flash"
echo "   • Default selection is 'Standard' (safer)"
echo ""
