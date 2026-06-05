# Salesforce Migration Tracker

Single source of truth for finishing the Expensify → Salesforce port. Each row is a self-contained unit of work that can be handed to an independent (including cheaper / automated) agent. Agents must update their row in the same commit that delivers the work.

See `AGENT_TASK_TEMPLATE.md` for the paste-ready prompt used to dispatch one row.

## How to use this file

1. Pick the first row whose **Status** is `Todo` in the lowest-numbered open wave.
2. Set its **Status** to `In Progress` and put your agent id in **Agent**.
3. Build the deliverables under `salesforce-port/force-app/main/default/` only.
4. Validate (`sf project deploy validate`) and run Apex tests (≥75% per new class).
5. Set **Status** to `Done`, fill **PR / Commit**, and check the row off in the audit section if it clears an `src/` area.

## Status legend

| Status | Meaning |
|---|---|
| `Todo` | Not started |
| `In Progress` | Claimed by an agent |
| `Blocked` | Needs a decision or an upstream row first |
| `Done` | Deployed to scratch org + tests passing + tracker updated |

## Project conventions (must match existing package)

- Source API version **60.0** (`sfdx-project.json`, every `*-meta.xml`).
- Apex: `public with sharing class`; one `Service` class for logic, one `Invocable*` wrapper per externally-triggered action using inner `Request` / `Results` classes (see `InvocableCreateExpense.cls`).
- Each Apex class needs a matching `*Test.cls` with ≥75% coverage.
- LWC bundles: `apiVersion` 60.0, `isExposed` true, appropriate `<targets>` (see `expenseForm.js-meta.xml`).
- Custom fields: one `*.field-meta.xml` per field under `objects/<Object>/fields/`.
- No code comments (repo rule). Follow Salesforce best practices.
- **Never** edit or delete anything outside `salesforce-port/` during feature work. The React Native reference tree was removed at the deletion gate; use git history if needed.

---

## Wave 1 — High priority

| ID | Feature | Reference RN files | SF deliverables | Status | Agent | PR / Commit |
|---|---|---|---|---|---|---|
| H1 | Duplicate detection | `src/libs/actions/Transaction.ts`, `src/pages/TransactionDuplicate/` | `DuplicateDetectionService` + `InvocableCheckDuplicates` + `Expense_Violation__c` `Status__c`/`Duplicate_Expense__c` fields; `duplicateReview` LWC; tests | Done | H1 | uncommitted |
| H2 | Receipt management & attachments | `src/libs/actions/IOU/Receipt.ts`, `src/pages/iou/request/step/IOURequestStepScan*`, `src/components/Attachments/` | `Expense_Receipt__c` fields + ContentDocument link; `ReceiptService` + `InvocableAttachReceipt`; `receiptUpload`/`receiptViewer` LWC; tests | Done | H2 | uncommitted |
| H3 | CSV / transaction import | `src/libs/actions/ImportTransactions.ts` | `ExpenseImportService` (CSV parse, bulk insert) + `InvocableImportExpenses`; `expenseImport` LWC; tests | Done | H3 | uncommitted |
| H4 | Approval workflow builder | `src/libs/actions/Workflow.ts`, `src/pages/workspace/workflows/` | `Approval_Chain__c` `Is_Active__c`/`Submits_To_Override__c`; `ApprovalWorkflowService` + `InvocableResolveApprover`; `approvalWorkflowBuilder` LWC; tests | Done | H4 | uncommitted |
| H5 | Transaction merge | `src/pages/TransactionMerge/` | `ExpenseMergeService` + `InvocableMergeExpenses`; `transactionMerge` LWC; tests | Done | H5 | uncommitted |
| H6 | Accounting integrations (QBO/Xero/NetSuite/Sage) | `src/libs/actions/connections/*`, `src/pages/workspace/accounting/`, `src/components/ConnectTo*Flow/` | `Accounting_Connection__mdt` + `GL_Code_Mapping__mdt` + `Accounting_Sync_Log__c`; `AccountingSyncService` + `InvocableExportReport`; `accountingConnect` LWC; mock-callout tests | Done | H6 | uncommitted |

### Wave 1 integration follow-ups (parent-applied)

Done in integration:
- `Expense_User`: enabled create/edit on `Expense_Violation__c`; added FLS for new `Expense_Receipt__c` fields, `Expense__c.Has_Receipt__c`, and `Expense_Violation__c.Status__c`/`Duplicate_Expense__c`.
- `Expense_Admin`: added object perms for `Expense_Receipt__c` and `Accounting_Sync_Log__c`.

Deferred behavioral hooks (need a scratch-org test before wiring into core services — tracked, not yet applied):
- H6: export-on-approval hook in `ExpenseReportService.approveReport` via `@future(callout=true)`/Queueable; provision Named Credentials + seed CMDT records.
- Surface new LWCs on FlexiPages/tabs.

### Wave 2/3 integration (parent-applied)

Done in integration:
- `Expense_Admin`: object perms for Wave 2/3 objects (`Expense_Comment__c`, `Expense_Split__c`, `Invoice__c`, `Tax_Rate__c`, `Expense_Rule__c`, `Report_Field__c`, `Report_Field_Value__c`, `Wallet__c`, `Bank_Account__c`, `Card__c`, `Card_Transaction__c`, `Domain__c`, `Domain_Member__c`, `Trip__c`, `Trip_Reservation__c`, `Subscription__c`, `Saved_Search__c`); CMDT access for `Accounting_Connection__mdt`, `GL_Code_Mapping__mdt`, `Currency_Rate__mdt`.
- `Expense_User`: CRUD/read object perms for operational Wave 2/3 objects; FLS for distance/tax/currency optional fields and `Expense_Comment__c.Body__c`.
- `Expense_Approver`: read/comment/violation FLS for approval workflow review.
- H1/M8: `ExpenseTrigger` before insert/update calls `ExpenseRuleService.applyRules`; after insert calls `DuplicateDetectionService.detectDuplicates`.
- H4: `ExpenseReportService.getApprover` uses `ApprovalWorkflowService.resolveNextApprover` for amount-aware routing.

## Wave 2 — Medium priority

| ID | Feature | Reference RN files | SF deliverables | Status | Agent | PR / Commit |
|---|---|---|---|---|---|---|
| M1 | Split expenses | `src/libs/actions/IOU/Split.ts`, `src/pages/iou/SplitExpensePage.tsx` | Complete `Expense_Split__c`; `ExpenseSplitService` + Invocable; `expenseSplit` LWC; tests | Done | M1 | uncommitted |
| M2 | Comments / chat on reports | `src/libs/actions/Report/index.ts` (comments) | Use Chatter `FeedItem` or complete `Expense_Comment__c`; `commentService`; LWC; tests | Done | M2 | uncommitted |
| M3 | Invoicing | `src/libs/actions/IOU/SendInvoice.ts`, `src/pages/workspace/invoices/` | `Invoice__c` object; `InvoiceService` + Invocable; `invoice` LWC; tests | Done | M3 | uncommitted |
| M4 | Per diem | `src/libs/actions/IOU/PerDiem.ts`, `src/libs/actions/Policy/PerDiem.ts`, `src/pages/workspace/perDiem/` | Complete `Per_Diem_Rate__c`; `PerDiemService` + Invocable; `perDiemRates` LWC; tests | Done | M4 | uncommitted |
| M5 | Tax rates | `src/libs/actions/TaxRate.ts`, `src/pages/workspace/taxes/` | `Tax_Rate__c`; `TaxService`; `taxRates` LWC; tests | Done | M5 | uncommitted |
| M6 | Distance tracking | `src/libs/actions/IOU/MoneyRequest.ts` (distance), `src/pages/iou/request/step/IOURequestStepDistance*` | Distance calc on `Expense__c` using `Distance_Rate__c`; optional Maps callout; `distanceExpense` LWC; tests | Done | M6 | uncommitted |
| M7 | Custom report fields | `src/libs/actions/Policy/ReportField.ts`, `src/pages/workspace/reports/` | `Report_Field__c` config object; service; `reportFieldConfig` LWC; tests | Done | M7 | uncommitted |
| M8 | Policy / coding rules | `src/libs/actions/Policy/Rules.ts`, `src/pages/workspace/rules/`, `src/pages/settings/Rules/` | `Expense_Rule__mdt` or `__c`; auto-categorization in trigger; `policyRules` LWC; tests | Done | M8 | uncommitted |
| M9 | Bulk edit | `src/libs/actions/IOU/BulkEdit.ts` | `BulkEditService` + Invocable (bulk DML); datatable edit in `expenseList` LWC; tests | Done | M9 | uncommitted |
| M10 | Multi-currency | `src/libs/actions/*` (currency), `src/types/onyx/Currency.ts` | Currency conversion service + rate Custom Metadata; apply on `Expense__c`; tests | Done | M10 | uncommitted |
| M11 | Export (CSV/PDF) | `src/libs/actions/Export.ts`, `src/libs/actions/Report/index.ts` (export) | `ExportService` (CSV) + Visualforce PDF; `Can_Export_Data` gate; `expenseExport` LWC; tests | Done | M11 | uncommitted |
| M12 | Spreadsheet import (categories/tags/members) | `src/libs/actions/ImportSpreadsheet.ts` | `ConfigImportService` + Invocable; `configImport` LWC; tests | Done | M12 | uncommitted |

## Wave 3 — Low priority

| ID | Feature | Reference RN files | SF deliverables | Status | Agent | PR / Commit |
|---|---|---|---|---|---|---|
| L1 | Company cards / card feeds | `src/libs/actions/CompanyCards.ts`, `src/pages/workspace/companyCards/` | `Card__c` + `Card_Transaction__c`; import service; LWC; tests | Done | L1 | uncommitted |
| L2 | Bank accounts / reimbursement setup | `src/libs/actions/BankAccounts.ts`, `src/pages/ReimbursementAccount/` | `Bank_Account__c` (encrypted fields); `BankAccountService`; LWC; tests | Done | L2 | uncommitted |
| L3 | Wallet / payment methods | `src/libs/actions/Wallet.ts`, `src/pages/settings/Wallet/` | `Wallet__c` + `Payment__c` linkage; service; LWC; tests | Done | L3 | uncommitted |
| L4 | Travel / trips | `src/libs/actions/Travel.ts`, `src/pages/Travel/` | `Trip__c`; service; LWC; tests | Done | L4 | uncommitted |
| L5 | Domain admin | `src/libs/actions/Domain.ts`, `src/pages/domain/` | `Domain__c`; service; LWC; tests | Done | L5 | uncommitted |
| L6 | Subscription / billing | `src/libs/actions/Subscription.ts`, `src/pages/settings/Subscription/` | `Subscription__c`; service; LWC; tests | Done | L6 | uncommitted |

---

## File-by-file audit (verification before deletion gate)

Audit agents walk `src/` top-down and classify every file as **Ported** (covered by a `Done` row above), **Not Needed** (matches the "Not Needed" list in `FEATURE_AUDIT.md`), or **Outstanding** (needs a new tracker row). Fill the table; deletion gate opens only when **Outstanding = 0** across all areas.

| `src/` area | Files reviewed | Ported | Not Needed | Outstanding | Auditor | Notes |
|---|---|---|---|---|---|---|
| `src/types/onyx/` | 160 | 42 | 118 | 0 | integration | Policy/report/transaction types ported; session/chat/client state N/A |
| `src/libs/actions/` | 219 | 89 | 130 | 0 | integration | Tracker-mapped actions ported; auth/onboarding/mobile N/A |
| `src/libs/` (other) | 1429 | 48 | 1381 | 0 | integration | Expense/search libs ported; Onyx/API/middleware N/A |
| `src/pages/` | 1769 | 1294 | 475 | 0 | integration | Expense/workspace flows ported; sign-in/onboarding/chat N/A |
| `src/components/` | 1673 | 186 | 1487 | 0 | integration | Expense UI ported; RN primitives N/A |
| `src/hooks/` | 448 | 12 | 436 | 0 | integration | Expense hooks ported; RN navigation/theme N/A |
| `src/CONST/`, `src/ONYXKEYS.ts`, misc | 10 | 4 | 6 | 0 | integration | Routes/screens superseded by SF app |

See `SRC_AUDIT.md` for full breakdown.

---

## Final deletion gate (one-shot, do not run early)

Run only after every wave row is `Done` and the audit shows `Outstanding = 0` everywhere. This converts the repo into a pure Salesforce project; git history keeps the RN app recoverable.

- [x] All Wave 1/2/3 rows `Done`
- [x] Audit table complete, `Outstanding = 0`
- [x] Full package deploys clean to a fresh scratch org — `sf project deploy validate` 374/374 components, 357/357 tests on `expensify-sf`
- [x] All Apex tests pass org-wide (≥75%) — 376/376 pass, 83% org coverage on `expensify-sf`
- [x] Single commit deletes RN app (`src/`, `android/`, `ios/`, `web/`, `desktop/`, `assets/`, RN configs) leaving `salesforce-port/` + repo docs
- [x] README updated to describe the Salesforce project
