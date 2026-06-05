# React Native Source Audit

Verification that every `src/` area is accounted for before the RN deletion gate. Classification rules are in `FEATURE_AUDIT.md` section 3 (Not Needed) and wave rows in `MIGRATION_TRACKER.md` (Ported).

Run `scripts/audit-src.ps1` from `salesforce-port/` to regenerate counts.

## Summary

| Area | Files | Ported | Not Needed | Outstanding |
|------|------:|-------:|-----------:|------------:|
| `src/types/onyx/` | 160 | 42 | 118 | 0 |
| `src/libs/actions/` | 219 | 89 | 130 | 0 |
| `src/libs/` (excl. actions) | 1,429 | 48 | 1,381 | 0 |
| `src/pages/` | 1,769 | 1,294 | 475 | 0 |
| `src/components/` | 1,673 | 186 | 1,487 | 0 |
| `src/hooks/` | 448 | 12 | 436 | 0 |
| `src/CONST/`, `ONYXKEYS.ts`, misc | 10 | 4 | 6 | 0 |
| **Total** | **5,708** | **1,675** | **4,033** | **0** |

Outstanding = 0 across all areas. Deletion gate may proceed when org tests and deploy checks are green.

## Ported (by wave)

All H1–H6, M1–M12, and L1–L6 tracker rows are `Done`. RN reference paths in each row map to Apex services, objects, and LWCs under `salesforce-port/force-app/main/default/`.

Core ported RN surfaces:

- Expenses, reports, policies, categories, tags, violations, payments
- Duplicate detection, receipts, CSV import, merge, approval chains, accounting sync
- Split, comments, invoicing, per diem, tax, distance, report fields, rules, bulk edit, multi-currency, export, config import
- Company cards, bank accounts, wallet, travel, domain admin, subscription

## Not Needed (representative)

- **Platform**: Session, Onyx, Pusher, API client, offline queue, middleware, optimistic updates
- **Mobile**: HybridApp, native attachments cache, GPS drafts, keyboard/safe-area, app updates
- **Auth/onboarding**: Sign-in, MFA, onboarding wizards, KYC/Onfido, Plaid link flows
- **Chat/social**: Composer, reactions, threads, rooms, emoji picker
- **Expensify-only**: TeachersUnite, Agent/Concierge, Tour, ExitSurvey, Chronos
- **UI primitives**: Skeletons, Lottie, FAB, theme/locale providers (replaced by SLDS/LWC)

## Outstanding

None. Remaining RN files are either covered by a `Done` tracker row or classified Not Needed per `FEATURE_AUDIT.md`.
