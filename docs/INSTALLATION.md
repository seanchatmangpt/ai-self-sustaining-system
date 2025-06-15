# 🛠️ Complete Installation Guide

## System Requirements

- macOS, Linux, or Windows (with WSL2)
- At least 8GB RAM
- 10GB free disk space

## Step-by-Step Installation

### 1. Install Elixir

**macOS (using Homebrew):**
```bash
brew install elixir
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install elixir
```

### 2. Install PostgreSQL

**macOS:**
```bash
brew install postgresql@14
brew services start postgresql@14
```

**Ubuntu/Debian:**
```bash
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
```

### 3. Install Node.js (v20.15 or higher)

**Using Node Version Manager (recommended):**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 20
nvm use 20
```

### 4. Install n8n

**Option A: Global Installation (requires sudo):**
```bash
sudo npm install -g n8n
```

**Option B: Using npx (no installation needed):**
```bash
# Just use npx n8n when needed
```

**Option C: Using Docker:**
```bash
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n
```

### 5. Install Claude Desktop

1. Download from: https://claude.ai/download
2. Install the application
3. Sign in with your account

### 6. Install Desktop Commander

```bash
npx @wonderwhy-er/desktop-commander@latest setup
```

### 7. Install n8n MCP Server

```bash
sudo npm install -g n8n-mcp-server
```

Or install locally:
```bash
cd /Users/sac/dev/ai-self-sustaining-system
npm install n8n-mcp-server
```

### 8. Install MCP Proxy (for SSE support)

**Using Rust (recommended):**
```bash
# Install Rust if not already installed
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install MCP Proxy
cargo install --git https://github.com/tidewave-ai/mcp_proxy_rust
```

## Verification

Run these commands to verify everything is installed:

```bash
# Check versions
elixir --version
psql --version
node --version
n8n --version || echo "n8n will be run with npx"
claude --version || echo "Claude Desktop app installed separately"

# Check MCP tools
which mcp-proxy || echo "MCP proxy may need PATH update"
```

## Common Issues

### Permission Errors

If you get permission errors with npm:
```bash
# Configure npm to use a different directory
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc
source ~/.zshrc
```

### PostgreSQL Connection Issues

```bash
# Create a user if needed
createuser -s postgres

# Start PostgreSQL
brew services start postgresql@14  # macOS
sudo systemctl start postgresql     # Linux
```

### Node Version Too Old

n8n requires Node.js 20.15 or higher:
```bash
nvm install 20
nvm alias default 20
```

## Next Steps

Once everything is installed, continue with the Quick Start Guide:
```bash
cat QUICKSTART.md
```
