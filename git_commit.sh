#!/bin/bash

# 1. Ensure .gitignore is configured correctly
echo "eks-key.pem" >> .gitignore
echo "*.jar" >> .gitignore
# Remove duplicates and empty lines
sort -u .gitignore -o .gitignore

# 2. Force-remove files from the Git index (stops them from being tracked)
# This does NOT delete the physical files on your disk.
git rm --cached eks-key.pem > /dev/null 2>&1 || true
git rm --cached *.jar > /dev/null 2>&1 || true

# 3. Add remaining files and commit
git add .
echo "Enter commit message:"
read -r msg

if [ -n "$msg" ]; then
    git commit -m "$msg"
    git push origin $(git rev-parse --abbrev-ref HEAD)
    echo "✅ Pushed to GitHub (excluding keys and JARs)."
else
    echo "❌ Commit aborted: No message provided."
fi
