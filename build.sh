#!/bin/bash

set -e

echo "🚀 Starting to build dify-python-sdk..."
echo ""

# Clean old build files
echo "📦 Cleaning old build files..."
rm -rf build dist

# Ensure uv is installed
if ! command -v uv &> /dev/null; then
    echo "❌ uv is not installed. Please install it first:"
    echo "   curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Build package using uv
echo "🏗️  Building wheel and sdist with uv..."
uv build

# Check if twine is available
echo "🔧 Checking for twine..."
if ! command -v twine &> /dev/null && ! python -m twine --version &> /dev/null 2>&1; then
    echo "⚠️  twine is not installed. Installing with uv tool..."
    uv tool install twine || {
        echo "⚠️  Failed to install twine with uv tool, trying pip..."
        pip install --user twine || {
            echo "⚠️  Could not install twine. Skipping integrity check."
            echo "    To upload manually later, install twine and run:"
            echo "    twine check dist/* && twine upload --repository pypi dist/*"
            exit 0
        }
    }
fi

# Check build artifacts
echo "✅ Checking package integrity..."
twine check dist/*

# Show build artifacts
echo ""
echo "📋 Build completed! Package info:"
ls -lh dist/
echo ""

# Verify version in built packages
echo "🔍 Verifying package version..."
BUILT_VERSION=$(ls dist/*.whl | grep -oP '\d+\.\d+\.\d+' | head -1)
echo "   Built version: $BUILT_VERSION"
echo ""

# Ask user whether to upload
read -p "Upload to PyPI? (yes/no): " confirm

if [ "$confirm" == "yes" ]; then
    echo "📤 Uploading to PyPI..."
    twine upload --repository pypi dist/*
    echo "✅ Upload successful!"
    echo "📦 Installation command: pip install dify-python-sdk"
else
    echo "⏸️  Upload cancelled"
    echo "💡 To upload later, run: twine upload --repository pypi dist/*"
fi
