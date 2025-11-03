# Challenge - AI Email Sorter

An intelligent email management application that automatically categorizes and summarizes your emails using AI. Built with Elixir, Phoenix LiveView, and OpenAI.

## 🚀 Live Demo

**[Try Live](https://ai-email-sorting-app-jatm.onrender.com)** - Experience the AI email sorting in action!

## Tech Stack

- **Elixir** 1.14+
- **Phoenix LiveView** 0.18+
- **PostgreSQL** 14+
- **Google OAuth** - Authentication via Google Sign-In
- **Tailwind CSS** - Utility-first CSS framework
- **Render.com** - Deployment platform (no credit card required!)
- **OpenAI GPT-4o-mini** - AI categorization and summarization

## Features

- ✅ **Google OAuth** with Gmail API integration
- ✅ **AI-Powered Email Categorization** - Automatically sort emails into custom categories
- ✅ **AI Email Summaries** - Get concise summaries of each email
- ✅ **Auto-Archive** - Emails are archived in Gmail after import
- ✅ **Multiple Gmail Accounts** - Connect and manage multiple inboxes
- ✅ **Bulk Actions** - Select and delete multiple emails at once
- ✅ **AI-Powered Unsubscribe** - Experimental feature to automatically unsubscribe from emails
- ✅ **Background Email Sync** - Automatic email synchronization every 5 minutes
- ✅ **Modern UI** with Tailwind CSS and Phoenix LiveView
- ✅ **Comprehensive Tests** - Full test coverage for contexts, LiveViews, and workers
- ✅ **Production Ready** - Render.com deployment configuration included

## Prerequisites

- Elixir 1.14+ installed
- Erlang/OTP 25+
- PostgreSQL 14+ running locally
- Node.js 18+ (for asset compilation)
- Render.com account (for deployment - free, no credit card required!)

## Quick Start

See [SETUP.md](SETUP.md) for detailed setup instructions.

## Getting Started

### 1. Install Dependencies

```bash
mix deps.get
cd assets && npm install && cd ..
```

### 2. Set Up Database

```bash
# Create and migrate database
mix ecto.setup
```

### 3. Configure Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Gmail API
4. Go to "Credentials" and create an OAuth 2.0 Client ID
5. Add authorized redirect URIs:
   - Development: `http://localhost:4000/auth/google/callback`
   - Production (Render): `https://ai-email-sorting-app-jatm.onrender.com/auth/google/callback`
6. Copy your Client ID and Client Secret

### 4. Configure Environment Variables

Create a `.env` file (not committed to git):

```bash
# Development
export GOOGLE_CLIENT_ID="your-google-client-id"
export GOOGLE_CLIENT_SECRET="your-google-client-secret"
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export GUARDIAN_SECRET_KEY="$(mix phx.gen.secret)"
export OPENAI_API_KEY="your-openai-api-key"
export CLOAK_KEY="$(elixir -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))')"
```

For production, set these in your deployment environment.

### 5. Run the Application

```bash
# Start Phoenix server
mix phx.server
```

Visit `http://localhost:4000` in your browser.

## Development

### Running Tests

```bash
mix test
```

### Code Formatting

```bash
mix format
```

### Database Migrations

```bash
# Create a new migration
mix ecto.gen.migration add_something_to_table

# Run migrations
mix ecto.migrate

# Rollback
mix ecto.rollback
```

## Project Structure

```
├── assets/                 # Frontend assets (JS, CSS)
├── config/                 # Application configuration
├── lib/
│   ├── jump/              # Application core
│   │   ├── accounts.ex    # Accounts context
│   │   └── repo.ex        # Ecto repository
│   └── jump_web/          # Web layer
│       ├── controllers/   # Phoenix controllers
│       ├── live/          # LiveView modules
│       ├── plugs/         # Plug modules (auth, etc.)
│       └── router.ex      # Routes
├── priv/
│   └── repo/
│       └── migrations/    # Database migrations
├── .github/
│   └── workflows/         # GitHub Actions (optional)
├── Dockerfile             # Docker configuration (optional)
├── render.yaml            # Render.com configuration
└── mix.exs               # Elixir project configuration
```

## Environment Variables

### Required for All Environments

- `SECRET_KEY_BASE` - Phoenix secret key base (generate with `mix phx.gen.secret`)
- `GUARDIAN_SECRET_KEY` - Guardian JWT secret key (generate with `mix phx.gen.secret`)
- `GOOGLE_CLIENT_ID` - Google OAuth client ID
- `GOOGLE_CLIENT_SECRET` - Google OAuth client secret
- `OPENAI_API_KEY` - OpenAI API key for email categorization and summarization
- `CLOAK_KEY` - Encryption key for sensitive data (generate with above command)

### Production/Database

- `DATABASE_URL` - PostgreSQL connection string (e.g., `ecto://user:password@host/database`)
- `PORT` - Port to run the application on (default: 4000)
- `POOL_SIZE` - Database connection pool size (default: 10)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

**John Michael Vibar**

- **Email**: [johnvincentvibar@gmail.com](mailto:johnvincentvibar@gmail.com)

## Support

For issues and questions, please open an issue on GitHub or contact the author directly.

