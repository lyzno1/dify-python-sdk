#!/bin/bash

# Sync upstream dify python-client manually
# Usage: ./sync-upstream.sh [--dry-run]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UPSTREAM_REPO="https://github.com/langgenius/dify-python-sdk.git"
UPSTREAM_BRANCH="main"
UPSTREAM_PATH="dify_client"
UPSTREAM_PYTHON_CLIENT="."
LOCAL_TARGET="dify_client"
UPSTREAM_REFERENCE=".upstream-reference"
SYNC_COMMIT_FILE=".github/.upstream-sync-commit"

# Parse arguments
DRY_RUN=false
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
    echo -e "${YELLOW}🔍 Running in DRY RUN mode - no changes will be made${NC}"
    echo ""
fi

echo -e "${BLUE}🔄 Manual Upstream Sync Script${NC}"
echo "================================================"
echo ""

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Warning: You have uncommitted changes${NC}"
    read -p "Continue anyway? (yes/no): " continue_dirty
    if [ "$continue_dirty" != "yes" ]; then
        echo -e "${RED}❌ Aborted${NC}"
        exit 1
    fi
    echo ""
fi

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}📍 Current branch: ${CURRENT_BRANCH}${NC}"

if [ "$CURRENT_BRANCH" == "main" ] && [ "$DRY_RUN" == "false" ]; then
    echo -e "${YELLOW}⚠️  Warning: You are on the main branch${NC}"
    read -p "Create a new branch for sync? (yes/no): " create_branch
    if [ "$create_branch" == "yes" ]; then
        BRANCH_NAME="sync/upstream-manual-$(date +%Y%m%d-%H%M%S)"
        git checkout -b "$BRANCH_NAME"
        echo -e "${GREEN}✅ Created and switched to branch: ${BRANCH_NAME}${NC}"
        echo ""
    fi
fi

# Add or update upstream remote
echo -e "${BLUE}🔗 Setting up upstream remote...${NC}"
if git remote get-url upstream > /dev/null 2>&1; then
    echo "   Upstream remote already exists"
    git remote set-url upstream "$UPSTREAM_REPO"
else
    git remote add upstream "$UPSTREAM_REPO"
    echo "   Added upstream remote"
fi
echo ""

# Fetch upstream
echo -e "${BLUE}📥 Fetching upstream changes...${NC}"
git fetch upstream "$UPSTREAM_BRANCH"
echo -e "${GREEN}✅ Fetch completed${NC}"
echo ""

# Get upstream commit hash
UPSTREAM_HASH=$(git log upstream/$UPSTREAM_BRANCH -1 --format="%H" -- $UPSTREAM_PATH)
UPSTREAM_SHORT="${UPSTREAM_HASH:0:7}"
echo -e "${BLUE}📝 Upstream commit: ${UPSTREAM_SHORT}${NC}"

# Check last sync
if [ -f "$SYNC_COMMIT_FILE" ]; then
    LAST_SYNC=$(cat "$SYNC_COMMIT_FILE")
    LAST_SYNC_SHORT="${LAST_SYNC:0:7}"
    echo -e "${BLUE}📝 Last synced commit: ${LAST_SYNC_SHORT}${NC}"

    if [ "$UPSTREAM_HASH" == "$LAST_SYNC" ]; then
        echo -e "${GREEN}✅ Already up to date with upstream${NC}"
        echo ""
        read -p "Sync anyway? (yes/no): " force_sync
        if [ "$force_sync" != "yes" ]; then
            echo -e "${BLUE}ℹ️  No sync performed${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}🆕 New changes available in upstream${NC}"
    fi
else
    echo -e "${YELLOW}ℹ️  No previous sync record found${NC}"
fi
echo ""

# Show what will be synced
echo -e "${BLUE}📦 Changes to sync from $UPSTREAM_PATH:${NC}"
git log --oneline "$LAST_SYNC..$UPSTREAM_HASH" -- $UPSTREAM_PATH 2>/dev/null || \
    git log --oneline upstream/$UPSTREAM_BRANCH -5 -- $UPSTREAM_PATH
echo ""

if [ "$DRY_RUN" == "true" ]; then
    echo -e "${YELLOW}🔍 DRY RUN: Would copy files from upstream/$UPSTREAM_BRANCH:$UPSTREAM_PATH to $LOCAL_TARGET${NC}"
    echo -e "${YELLOW}🔍 DRY RUN: Would update sync commit to $UPSTREAM_SHORT${NC}"
    echo ""
    echo -e "${GREEN}✅ Dry run completed - no changes made${NC}"
    exit 0
fi

# Confirm sync
read -p "Proceed with sync? (yes/no): " confirm_sync
if [ "$confirm_sync" != "yes" ]; then
    echo -e "${RED}❌ Sync cancelled${NC}"
    exit 0
fi
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Extract upstream files
echo -e "${BLUE}📦 Extracting upstream files...${NC}"
git archive upstream/$UPSTREAM_BRANCH "$UPSTREAM_PATH" README.md pyproject.toml | tar -x -C "$TEMP_DIR"

# Check if files were extracted
if [ ! -d "$TEMP_DIR/$UPSTREAM_PATH" ]; then
    echo -e "${RED}❌ Error: Failed to extract upstream files${NC}"
    exit 1
fi

# Backup current files
BACKUP_DIR="/tmp/dify-client-backup-$(date +%Y%m%d-%H%M%S)"
echo -e "${BLUE}💾 Creating backup at: ${BACKUP_DIR}${NC}"
mkdir -p "$BACKUP_DIR"
cp -r "$LOCAL_TARGET" "$BACKUP_DIR/" || true

# Copy code files
echo -e "${BLUE}📋 Copying code files from upstream $UPSTREAM_PATH...${NC}"
rsync -av --delete \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.pytest_cache' \
    "$TEMP_DIR/$UPSTREAM_PATH/" \
    "$LOCAL_TARGET/"

echo -e "${GREEN}✅ Code files copied successfully${NC}"
echo ""

# Copy config files to reference directory
echo -e "${BLUE}📋 Copying upstream config files to $UPSTREAM_REFERENCE...${NC}"
mkdir -p "$UPSTREAM_REFERENCE"

if [ -f "$TEMP_DIR/$UPSTREAM_PYTHON_CLIENT/README.md" ]; then
    cp "$TEMP_DIR/$UPSTREAM_PYTHON_CLIENT/README.md" "$UPSTREAM_REFERENCE/"
    echo -e "${GREEN}   ✅ Copied README.md${NC}"
fi

if [ -f "$TEMP_DIR/$UPSTREAM_PYTHON_CLIENT/pyproject.toml" ]; then
    cp "$TEMP_DIR/$UPSTREAM_PYTHON_CLIENT/pyproject.toml" "$UPSTREAM_REFERENCE/"
    echo -e "${GREEN}   ✅ Copied pyproject.toml${NC}"
fi

echo -e "${GREEN}✅ Config files copied successfully${NC}"
echo ""

# Show changes
echo -e "${BLUE}📊 Changes made:${NC}"
git diff --stat "$LOCAL_TARGET"
echo ""

# Check if there are actual changes
if git diff --quiet "$LOCAL_TARGET" "$UPSTREAM_REFERENCE"; then
    echo -e "${GREEN}ℹ️  No file changes detected (files are identical)${NC}"
    echo ""
    read -p "Update sync commit anyway? (yes/no): " update_anyway
    if [ "$update_anyway" != "yes" ]; then
        echo -e "${BLUE}ℹ️  Sync cancelled${NC}"
        exit 0
    fi
fi

# Update sync commit file
mkdir -p .github
echo "$UPSTREAM_HASH" > "$SYNC_COMMIT_FILE"
echo -e "${GREEN}✅ Updated sync commit record${NC}"
echo ""

# Stage changes
git add "$LOCAL_TARGET" "$UPSTREAM_REFERENCE" "$SYNC_COMMIT_FILE"

# Show commit preview
echo -e "${BLUE}📝 Commit preview:${NC}"
echo "---"
cat <<EOF
sync: update from upstream dify_client

Synced from langgenius/dify-python-sdk@$UPSTREAM_SHORT
Source: https://github.com/langgenius/dify-python-sdk/tree/$UPSTREAM_HASH/$UPSTREAM_PATH

Changes:
- Automatic sync from upstream repository
- Updated dify_client implementation
- Manual sync executed on $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Upstream commit: $UPSTREAM_HASH
EOF
echo "---"
echo ""

# Commit
read -p "Commit these changes? (yes/no): " confirm_commit
if [ "$confirm_commit" == "yes" ]; then
git commit -m "sync: update from upstream dify_client

Synced from langgenius/dify-python-sdk@$UPSTREAM_SHORT
Source: https://github.com/langgenius/dify-python-sdk/tree/$UPSTREAM_HASH/$UPSTREAM_PATH

Changes:
- Automatic sync from upstream repository
- Updated dify_client implementation
- Manual sync executed on $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Upstream commit: $UPSTREAM_HASH"

    echo -e "${GREEN}✅ Changes committed${NC}"
    echo ""

    # Show next steps
    echo -e "${BLUE}📋 Next steps:${NC}"
    echo "1. Review the changes: git show"
    echo "2. Push changes: git push origin $(git branch --show-current)"
    echo ""

    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "main" ]; then
        echo -e "${YELLOW}💡 Tip: Create a PR with:${NC}"
        echo "   gh pr create --fill"
    fi
else
    echo -e "${YELLOW}⚠️  Changes staged but not committed${NC}"
    echo ""
    echo "To commit manually:"
    echo "  git commit -m 'sync: update from upstream dify_client'"
    echo ""
    echo "To discard changes:"
    echo "  git reset HEAD $LOCAL_TARGET $UPSTREAM_REFERENCE $SYNC_COMMIT_FILE"
    echo "  git checkout -- $LOCAL_TARGET $UPSTREAM_REFERENCE"
fi

echo ""
echo -e "${GREEN}✅ Sync completed!${NC}"
echo ""
echo -e "${BLUE}ℹ️  Backup available at: ${BACKUP_DIR}${NC}"
