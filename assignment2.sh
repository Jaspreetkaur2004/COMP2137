#!/bin/bash

# Assignment 2 - COMP2137 Setup Script
# This script automates the setup of development tools for bash scripting

# Function to display colored messages
function message {
    echo -e "\e[1;34m$1\e[0m"
}

# Function to check if a command exists
function command_exists {
    command -v "$1" >/dev/null 2>&1
}

# Update package lists
message "Updating package lists..."
sudo apt update

# Install ShellCheck
message "Installing ShellCheck..."
if ! command_exists shellcheck; then
    sudo apt install -y shellcheck
    message "ShellCheck installed successfully."
else
    message "ShellCheck is already installed."
fi

# Generate SSH keys
message "Generating SSH keys..."
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    message "SSH keys generated successfully."
    
    # Display public key
    message "Your SSH public key is:"
    cat ~/.ssh/id_ed25519.pub
    echo ""
    
    message "Please manually add this key to your GitHub account:"
    message "1. Go to GitHub.com and log in"
    message "2. Click your profile picture → Settings → SSH and GPG keys"
    message "3. Click 'New SSH Key'"
    message "4. Paste the above key and save"
else
    message "SSH keys already exist."
fi

# Configure Git
message "Configuring Git..."
read -p "Enter your Git email address: " git_email
read -p "Enter your Git name: " git_name

git config --global user.email "$git_email"
git config --global user.name "$git_name"

message "Git configured with:"
message "Email: $git_email"
message "Name: $git_name"

# Clone repository (if not already exists)
message "Setting up COMP2137 repository..."
if [ ! -d ~/COMP2137 ]; then
    read -p "Enter your GitHub username: " github_username
    
    # Test SSH connection to GitHub
    message "Testing SSH connection to GitHub..."
    ssh -T git@github.com
    
    message "Cloning COMP2137 repository..."
    git clone git@github.com:$github_username/COMP2137.git ~/COMP2137
    
    if [ $? -eq 0 ]; then
        message "Repository cloned successfully to ~/COMP2137"
    else
        message "Failed to clone repository. Please ensure:"
        message "1. You've created the COMP2137 repo on GitHub"
        message "2. You've added your SSH key to GitHub"
        message "3. The repository exists at github.com/$github_username/COMP2137"
    fi
else
    message "COMP2137 directory already exists at ~/COMP2137"
fi

# Install optional tools
message "Would you like to install additional text editors? (nano/vim/gedit)"
read -p "Install additional editors? [y/N]: " install_editors

if [[ "$install_editors" =~ ^[Yy]$ ]]; then
    message "Installing additional editors..."
    sudo apt install -y nano vim gedit
    message "Editors installed: nano, vim, gedit"
fi

# Final instructions
message "\nSetup complete! Here's what to do next:"
message "1. Change to your project directory: cd ~/COMP2137"
message "2. Create/edit scripts using your preferred editor"
message "3. Use 'shellcheck your_script.sh' to check your scripts"
message "4. Use git to track changes:"
message "   - git add your_files"
message "   - git commit -m 'your message'"
message "   - git push"

message "\nRemember to always run shellcheck on your scripts before submitting!"
