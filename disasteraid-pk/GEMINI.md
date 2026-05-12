# ReliefNet App (DisasterAid PK) - Project Instructions

## Tech Stack
- **Frontend:** Flutter (Material 3)
- **Backend:** Node.js, Express.js (CommonJS)
- **Database:** PostgreSQL (via Supabase)
- **State Management:** Provider
- **Real-time:** Socket.io
- **Storage:** Cloudinary
- **Auth:** JWT-based RBAC (donor, ngo, admin, beneficiary, volunteer)

## Architectural Patterns
- **Backend:**
    - Module-based structure in `src/modules/`.
    - Middleware for auth, error handling, and validation.
    - `pg` pool for database interactions.
    - Atomic transactions for financial operations (donations -> wallets).
- **Frontend:**
    - Feature-first structure in `lib/features/`.
    - `core/` directory for API clients, auth providers, and shared services.
    - `shared/` for common UI components.
    - `Dio` for networking with interceptors for auth.

## Conventions
- **Naming:**
    - Backend: camelCase for variables/functions, PascalCase for classes (if any).
    - Frontend: standard Flutter conventions (lower_with_underscores for files, PascalCase for classes).
- **Testing:**
    - Backend: Jest and Supertest in `backend/tests/`.
    - Frontend: standard Flutter tests in `flutter_app/test/`.
- **Environment:**
    - Backend: `.env` file for secrets.
    - Frontend: `.env` file loaded via `flutter_dotenv`.

## Key Files
- `backend/src/server.js`: API entry point.
- `backend/src/config/db.js`: DB connection.
- `flutter_app/lib/main.dart`: App entry point.
- `docs/ARCHITECTURE.md`: High-level system design.
