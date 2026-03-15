#!/bin/bash

echo "=== 8BP Extended Guidelines - GitHub Setup ==="
echo ""

# Check if git is configured
if ! git config --global user.name > /dev/null 2>&1; then
    echo "[!] Git not configured. Let's set it up:"
    echo ""
    read -p "Enter your GitHub username: " username
    read -p "Enter your GitHub email: " email

    git config --global user.name "$username"
    git config --global user.email "$email"

    echo "[+] Git configured!"
    echo ""
fi

echo "Current git config:"
echo "  Name: $(git config --global user.name)"
echo "  Email: $(git config --global user.email)"
echo ""

# Get repository name
read -p "Enter your GitHub username: " gh_user
read -p "Enter repository name [8bp-extended-guidelines]: " repo_name
repo_name=${repo_name:-8bp-extended-guidelines}

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Create a new repository on GitHub:"
echo "   https://github.com/new"
echo "   - Name: $repo_name"
echo "   - Private: Yes (recommended)"
echo "   - Don't initialize with README"
echo ""
echo "2. After creating the repo, run these commands:"
echo ""
echo "   cd c:/Project/8bp_extended_guidelines"
echo "   git remote add origin https://github.com/$gh_user/$repo_name.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. GitHub Actions will automatically build the dylib"
echo ""
echo "4. Download the artifact from the Actions tab"
echo ""

read -p "Press Enter to continue..."
