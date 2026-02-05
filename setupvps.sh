#!/bin/bash
# ICTexel Development VPS Setup Script
# Voor Ubuntu 24.04 LTS op Hetzner

set -e  # Stop bij errors

echo "================================"
echo "ICTexel Development VPS Setup"
echo "================================"

# Kleuren voor output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Update systeem
print_status "Systeem updaten..."
sudo apt update && sudo apt upgrade -y
print_success "Systeem geüpdatet"

# Basis tools installeren
print_status "Basis development tools installeren..."
sudo apt install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    htop \
    net-tools \
    vim \
    tmux
print_success "Basis tools geïnstalleerd"

# Node.js 20 LTS installeren
print_status "Node.js 20 LTS installeren..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
print_success "Node.js $(node --version) geïnstalleerd"

# pnpm installeren (sneller dan npm)
print_status "pnpm installeren..."
curl -fsSL https://get.pnpm.io/install.sh | sh -
export PNPM_HOME="/root/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
print_success "pnpm geïnstalleerd"

# Docker installeren
print_status "Docker installeren..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
print_success "Docker geïnstalleerd"

# Docker Compose installeren (standalone)
print_status "Docker Compose installeren..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
print_success "Docker Compose geïnstalleerd"

# PostgreSQL client tools (voor psql commando)
print_status "PostgreSQL client tools installeren..."
sudo apt install -y postgresql-client
print_success "PostgreSQL client geïnstalleerd"

# Development directories aanmaken
print_status "Development directories aanmaken..."
mkdir -p ~/projects
mkdir -p ~/docker-data
print_success "Directories aangemaakt"

# Docker compose file voor databases
print_status "Database docker-compose.yml aanmaken..."
cat > ~/docker-data/docker-compose.yml <<'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: dev-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: devuser
      POSTGRES_PASSWORD: devpass
      POSTGRES_DB: devdb
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U devuser"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: dev-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres-data:
  redis-data:
EOF
print_success "Docker compose file aangemaakt"

# Git configuratie
print_status "Git configureren..."
git config --global init.defaultBranch main
git config --global pull.rebase false
print_success "Git geconfigureerd"

# Handige aliases toevoegen
print_status "Bash aliases toevoegen..."
cat >> ~/.bashrc <<'EOF'

# ICTexel Development Aliases
alias dc='docker-compose'
alias dps='docker ps'
alias dlog='docker-compose logs -f'
alias proj='cd ~/projects'
alias dbstart='cd ~/docker-data && docker-compose up -d'
alias dbstop='cd ~/docker-data && docker-compose down'
alias dbstatus='cd ~/docker-data && docker-compose ps'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# Handige functies
mkproj() {
    mkdir -p ~/projects/$1
    cd ~/projects/$1
    git init
    echo "# $1" > README.md
    echo "node_modules/" > .gitignore
    echo ".env" >> .gitignore
    echo "Project $1 aangemaakt!"
}
EOF
print_success "Aliases toegevoegd"

# Firewall configureren (alleen SSH en development poorten)
print_status "Firewall configureren..."
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 3000:3010/tcp  # Next.js, Vite, etc.
sudo ufw allow 5432/tcp       # PostgreSQL (optioneel, voor externe toegang)
sudo ufw --force enable
print_success "Firewall geconfigureerd"

# Automatic security updates
print_status "Automatic security updates instellen..."
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
print_success "Security updates ingesteld"

# Swap file aanmaken (voor VPS met weinig RAM)
print_status "Swap file aanmaken..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    print_success "2GB swap file aangemaakt"
else
    print_status "Swap file bestaat al"
fi

# Database containers starten
print_status "Database containers starten..."
cd ~/docker-data
docker-compose up -d
print_success "PostgreSQL en Redis draaien!"

echo ""
echo "================================"
echo "✓ Setup compleet!"
echo "================================"
echo ""
echo "Geïnstalleerd:"
echo "  - Node.js $(node --version)"
echo "  - npm $(npm --version)"
echo "  - pnpm $(pnpm --version)"
echo "  - Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  - PostgreSQL 16 (Docker)"
echo "  - Redis 7 (Docker)"
echo ""
echo "Database credentials:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  User: devuser"
echo "  Pass: devpass"
echo "  DB:   devdb"
echo ""
echo "Handige commando's:"
echo "  dbstart   - Start databases"
echo "  dbstop    - Stop databases"
echo "  dbstatus  - Check database status"
echo "  mkproj <naam> - Maak nieuw project"
echo "  proj      - Ga naar ~/projects"
echo ""
echo "⚠️  Herstart je terminal of run: source ~/.bashrc"
echo "⚠️  Voor Docker zonder sudo: log uit en weer in"
echo ""
echo "Volgende stap: Verbind met VS Code Remote SSH!"
echo "================================"
