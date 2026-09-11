# Deutsch-Mate 🇩🇪

A modern German language learning application built with **Flutter** and **FastAPI**, designed to help learners master German aligned to the **Menschen syllabus** (A1.1 to B1.2).

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Frontend Setup](#frontend-setup)
  - [Backend Setup](#backend-setup)
- [Running the Application](#running-the-application)
- [Development](#development)
- [Architecture](#architecture)
- [API Documentation](#api-documentation)
- [Contributing](#contributing)
- [License](#license)

## 📱 Overview

**Deutsch-Mate** is a comprehensive German language learning companion that combines a Flutter mobile application frontend with a FastAPI backend. The app is designed around the **Menschen textbook syllabus**, providing structured lessons from beginner (A1.1) to upper-intermediate (B1.2) levels.

The application features an **offline-first architecture**, meaning learners can access lesson content without an internet connection and sync their progress when they reconnect.

## ✨ Features

- **Structured Curriculum**: Lessons aligned to the Menschen syllabus (A1.1 to B1.2)
- **Offline-First**: Complete lesson content bundled with the app; no internet required for learning
- **User Authentication**: Secure email-based sign-up with verification and password recovery
- **Progress Tracking**: Account-linked progress that persists across device reinstalls
- **Spaced Repetition**: Leitner-based review system for vocabulary retention
- **Text-to-Speech**: Built-in pronunciation support via device TTS
- **Multi-language UI**: Support for German and Persian (Farsi) interface languages
- **Responsive Design**: Optimized for mobile, tablet, and web platforms

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter 3.27+
- **Language**: Dart 3.6+
- **State Management**: Native Flutter patterns
- **Storage**: Shared Preferences
- **Audio**: flutter_tts (text-to-speech)
- **Fonts**: 
  - Bricolage Grotesque (UI)
  - Instrument Sans (Interaction)
  - JetBrains Mono (Code/Monospace)
  - Vazirmatn (Persian)

### Backend
- **Framework**: FastAPI 0.141
- **Database**: MongoDB with Beanie ODM
- **Authentication**: JWT (HS256) + Opaque Rotating Tokens
- **Password Hashing**: argon2-cffi
- **Testing**: pytest + pytest-asyncio
- **Runtime**: Python 3.13

## 📁 Project Structure

```
Deutsch-Mate/
├── lib/                    # Flutter app source code
│   ├── core/              # Core utilities (audio, audio_helper, etc.)
│   └── ...
├── backend/               # FastAPI backend service
│   ├── app/
│   │   ├── config.py      # Settings & configuration
│   │   ├── errors.py      # Error definitions & handlers
│   │   ├── security.py    # Authentication & password security
│   │   ├── db.py          # MongoDB client & Beanie setup
│   │   ├── deps.py        # Dependency injection
│   │   ├── mail.py        # Email handling
│   │   ├── models/        # Beanie document models
│   │   ├── schemas/       # Request/response schemas
│   │   └── routers/       # API endpoints (auth, progress, content)
│   └── tests/             # Pytest suite (41 tests)
├── assets/
│   ├── data/              # Lesson content & vocabulary
│   ├── audio/             # Pronunciation audio files
│   └── fonts/             # Custom fonts
├── android/               # Android platform code
├── ios/                   # iOS platform code
├── web/                   # Web platform code
├── linux/                 # Linux platform code
├── macos/                 # macOS platform code
├── windows/               # Windows platform code
├── pubspec.yaml           # Flutter dependencies & configuration
└── analysis_options.yaml  # Lint rules

```

## 🚀 Getting Started

### Prerequisites

#### For Frontend
- **Flutter**: 3.27.0 or higher
- **Dart**: 3.6.0 or higher

#### For Backend
- **Python**: 3.13 (developed on 3.13.3)
- **MongoDB**: Running locally on `mongodb://127.0.0.1:27017`

### Frontend Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/AliiAriizii/Deutsch-Mate.git
   cd Deutsch-Mate
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Get the latest configuration**
   ```bash
   flutter pub upgrade
   ```

### Backend Setup

1. **Navigate to backend directory**
   ```bash
   cd backend
   ```

2. **Create a Python virtual environment**
   ```bash
   python -m venv .venv
   ```

3. **Activate the virtual environment**
   - **Windows**:
     ```bash
     .venv\Scripts\activate
     ```
   - **macOS/Linux**:
     ```bash
     source .venv/bin/activate
     ```

4. **Install dependencies**
   ```bash
   python -m pip install -r requirements-dev.txt
   ```

5. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` and set a real JWT secret:
   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(64))"
   ```

6. **Ensure MongoDB is running**
   ```bash
   mongod  # Default: mongodb://127.0.0.1:27017
   ```

## ▶️ Running the Application

### Frontend

**Run on default platform:**
```bash
flutter run
```

**Run on specific platform:**
```bash
flutter run -d <device-id>  # Mobile/tablet
flutter run -d chrome       # Web
flutter run -d linux        # Linux
flutter run -d macos        # macOS
flutter run -d windows      # Windows
```

**Build for release:**
```bash
flutter build apk     # Android
flutter build ios     # iOS
flutter build web     # Web
flutter build linux   # Linux
flutter build macos   # macOS
flutter build windows # Windows
```

### Backend

**Start the FastAPI development server:**
```bash
python -m uvicorn app.main:app --reload --port 8000
```

The backend will be available at:
- **API Base**: `http://127.0.0.1:8000`
- **Interactive Docs (Swagger UI)**: `http://127.0.0.1:8000/docs`
- **Alternative Docs (ReDoc)**: `http://127.0.0.1:8000/redoc`
- **Health Check**: `http://127.0.0.1:8000/api/v1/health`

## 🔧 Development

### Running Tests

#### Backend Tests
```bash
cd backend
python -m pytest              # Run all tests
python -m pytest -v           # Verbose output
python -m pytest -k "auth"    # Run specific test pattern
```

**Note**: Tests use the `deutschmate_test` database and drop it before every run, so development data is never affected.

### Flutter Analysis

Check for lint and style issues:
```bash
flutter analyze
```

Format code:
```bash
dart format lib/ backend/
```

### Code Organization

- **Frontend**: Following Flutter best practices with clear separation of concerns
- **Backend**: Modular routers separated by domain (auth, progress, content)
- **Database Models**: Pydantic-based validation in `app/models/`
- **Schemas**: Request/response contracts in `app/schemas/`

## 🏗️ Architecture

### Frontend Architecture
- **Offline-First**: Content bundled with app, manifest-based updates
- **State Management**: Native Flutter patterns with local caching
- **Asset Versioning**: Checksum-verified content updates without app store release

### Backend Architecture

#### Authentication Flow
- **Sign-up**: Email verification required before token issuance
- **Sign-in**: 15-minute account lockout after 10 failed attempts
- **Access Tokens**: Short-lived (30 min) JWT tokens
- **Refresh Tokens**: Opaque, rotating tokens with 60-day expiration
- **Session Revocation**: Password changes/resets revoke all sessions
- **Account Security**: Argon2-cffi for memory-hard password hashing

#### Progress Synchronization
- **Monotonic Fields**: Always take the max value from both sides
- **Status Progression**: Only moves forward, never rolls back
- **Deduplication**: `client_attempt_id` prevents double-counting on retries
- **Conflict Resolution**: Stale devices replaying old batches are no-ops

#### Content Management
- **Versioned Content**: Bundled levels with update manifest
- **Checksum Verification**: SHA-256 validation after download
- **Dynamic Updates**: Content changes push new versions without app release

### Error Handling
All API errors follow a consistent typed format:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message",
    "details": {}
  }
}
```

Validation errors include field-level details:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "fields": {
        "email": "Invalid email format"
      }
    }
  }
}
```

## 📚 API Documentation

The backend provides comprehensive REST API documentation:

### Authentication Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/auth/password-policy` | Get password requirements |
| POST | `/api/v1/auth/signup` | Create new account |
| POST/GET | `/api/v1/auth/verify-email` | Email verification |
| POST | `/api/v1/auth/resend-verification` | Resend verification email |
| POST | `/api/v1/auth/signin` | Sign in with credentials |
| POST | `/api/v1/auth/refresh` | Refresh access token |
| POST | `/api/v1/auth/logout` | Sign out (single or all devices) |
| POST | `/api/v1/auth/forgot-password` | Request password reset |
| POST | `/api/v1/auth/reset-password` | Reset password with code |
| POST | `/api/v1/auth/change-password` | Change password |
| GET | `/api/v1/auth/me` | Get current user info |
| POST | `/api/v1/auth/onboarding` | Complete onboarding |
| DELETE | `/api/v1/auth/me` | Delete account |

### Progress Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/progress` | Get all progress data |
| POST | `/api/v1/progress/sync` | Sync offline changes |
| GET | `/api/v1/progress/due-reviews` | Get items due for review |

### Content Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/content/manifest` | Get content version manifest |
| GET | `/api/v1/content/levels/{level_id}` | Get level content |
| POST | `/api/v1/content/packages` | Publish content (admin only) |

For detailed endpoint specifications, visit the interactive API docs at `http://127.0.0.1:8000/docs`

## 🔮 Roadmap

### Planned Features
- **Content Seeding**: Level packages with complete vocabulary and exercises
- **Placement Test**: Adaptive assessment to determine starting level
- **Rate Limiting**: Per-IP throttling at reverse proxy
- **Deployment**: Production-ready server configuration with TLS and CORS

### Currently In Development
- Core infrastructure and authentication system ✅
- Progress synchronization engine ✅
- Content management system (in progress)

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature`
3. **Commit** your changes: `git commit -am 'Add new feature'`
4. **Push** to the branch: `git push origin feature/your-feature`
5. **Submit** a pull request

### Code Standards
- Follow Dart style guide for frontend code
- Follow PEP 8 for Python backend code
- Add tests for new features
- Update documentation accordingly

## 📄 License

This project is open source. Please check the repository for license details.

## 🙋 Support

For questions or issues:
- Open a GitHub Issue
- Check existing documentation in `/docs`
- Review API documentation at `http://127.0.0.1:8000/docs`

## 🎓 About Menschen Syllabus

**Deutsch-Mate** follows the **Menschen** textbook series, a comprehensive German learning curriculum that progresses through these levels:
- **A1.1**: Absolute Beginner
- **A1.2**: Elementary
- **A2.1**: Elementary Intermediate
- **A2.2**: Pre-Intermediate
- **B1.1**: Intermediate
- **B1.2**: Upper-Intermediate

---

**Happy learning! Viel Erfolg beim Deutschlernen! 🎓**
