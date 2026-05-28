# Expensify to Salesforce Port — Feature Audit

This document categorizes every major module/feature from the Expensify App into three groups:
1. **Ported** — Recreated in the Salesforce implementation
2. **Not Ported** — Relevant features that have not yet been implemented
3. **Not Needed** — Features that are either platform-specific, handled natively by Salesforce, or not applicable

---

## 1. PORTED (Implemented in Salesforce)

### Data Model / Types (src/types/onyx/)

| Original | Salesforce Equivalent |
|----------|----------------------|
| `Policy.ts` — Workspace configuration | `Expense_Policy__c` custom object |
| `PolicyCategory.ts` — Expense categories | `Expense_Category__c` custom object |
| `PolicyTag.ts` — Expense tags | `Expense_Tag__c` custom object |
| `PolicyEmployee.ts` — Workspace members | `Policy_Member__c` custom object |
| `Report.ts` — Expense reports | `Expense_Report__c` custom object |
| `Transaction.ts` — Expenses | `Expense__c` custom object |
| `TransactionViolation.ts` — Policy violations | `Expense_Violation__c` custom object |
| `ApprovalWorkflow.ts` — Approval chains | `Approval_Chain__c` custom object |
| `SaveSearch.ts` — Saved searches | `Saved_Search__c` custom object |
| `IOU.ts` — Split expenses | `Expense_Split__c` custom object |

### Business Logic (src/libs/actions/)

| Original | Salesforce Equivalent |
|----------|----------------------|
| `IOU/TrackExpense.ts` — Create expenses | `ExpenseService.createExpense()` + `InvocableCreateExpense` |
| `IOU/UpdateMoneyRequest.ts` — Update expenses | `ExpenseService.updateExpense()` |
| `IOU/DeleteMoneyRequest.ts` — Delete expenses | `ExpenseService.deleteExpense()` |
| `IOU/Hold.ts` — Hold expenses | `ExpenseService.holdExpense()` + `InvocableHoldExpense` |
| `IOU/ReportWorkflow.ts` — Submit report | `ExpenseReportService.submitReport()` + `InvocableSubmitReport` |
| `IOU/ReportWorkflow.ts` — Approve report | `ExpenseReportService.approveReport()` + `InvocableApproveReport` |
| `IOU/RejectMoneyRequest.ts` — Reject | `ExpenseReportService.rejectReport()` + `InvocableRejectReport` |
| `IOU/ReportWorkflow.ts` — Reopen report | `ExpenseReportService.reopenReport()` + `InvocableReopenReport` |
| `IOU/PayMoneyRequest.ts` — Mark reimbursed | `ExpenseReportService.markReimbursed()` + `InvocableMarkReimbursed` |
| `Policy/Policy.ts` — Create workspace | `PolicyService.createPolicy()` |
| `Policy/Member.ts` — Add/remove members | `PolicyService.addMember()/removeMember()` + Invocables |
| `Policy/Category.ts` — Category CRUD | `PolicyService.createCategory()/getCategories()` |
| `Policy/Tag.ts` — Tag CRUD | `PolicyService.createTag()/getTags()` |
| `Policy/DistanceRate.ts` — Distance rates | `PolicyService.createDistanceRate()/getDistanceRates()` |
| `Search.ts` — Search expenses | `ExpenseController.searchExpenses()` |
| Violation detection logic | `ExpenseService.checkViolations()` + `InvocableCheckViolations` |
| Auto-approval logic | `ExpenseReportService.submitReport()` (auto-approve check) |
| Report total rollup | `ExpenseTriggerHandler` + `ExpenseService.updateReportTotals()` |

### Pages / UI (src/pages/)

| Original | Salesforce Equivalent |
|----------|----------------------|
| `home/` — Dashboard | `expenseDashboard` LWC |
| `iou/` — Expense creation flow | `expenseForm` LWC |
| `inbox/` — Expense list | `expenseList` LWC |
| `Search/` — Search page | `expenseSearch` LWC |
| `workspace/` — Workspace settings | `workspaceSettings` LWC |
| Report list & detail pages | `expenseReportList` + `expenseReportDetail` LWCs |
| Approval actions (approve/reject) | `expenseReportDetail` LWC actions |

### Security & Permissions

| Original | Salesforce Equivalent |
|----------|----------------------|
| Policy role checks (Admin/Approver/Member/Auditor) | Permission Sets + `Policy_Member__c.Role__c` |
| Report submission eligibility | Apex service guard logic |
| Report approval eligibility | Apex service guard logic |
| Feature-level access control | Custom Permissions |

### Automation

| Original | Salesforce Equivalent |
|----------|----------------------|
| Auto-submit (scheduled) | `Scheduled_Expense_Report_Submit` Flow |
| Violation detection (on create/update) | `Expense_Violation_Check` Flow + Apex trigger |
| Report total recalculation | `ExpenseTrigger` + `ExpenseTriggerHandler` |
| Event notifications | Platform Events (Submitted/Approved/Rejected) |

---

## 2. NOT PORTED (Relevant but not yet implemented)

### Data Model / Types

| Original | What It Does | Priority |
|----------|--------------|----------|
| `Card.ts` — Expensify/company cards | Card management and transactions | Medium |
| `BankAccount.ts` — Bank accounts | Bank account linking | Medium |
| `Fund.ts` — Debit card funds | Payment methods | Low |
| `UserWallet.ts` — Wallet | Wallet balance and payments | Low |
| `PersonalDetails.ts` — User profiles | Extended user profile data | Medium |
| `PrivatePersonalDetails.ts` — Legal name, DOB | KYC/personal details | Low |
| `TripData.ts` — Travel reservations | Trip booking data | Low |
| `TravelSettings.ts` — Travel policy | Travel feature config | Low |
| `Domain.ts` — Domain control | Enterprise domain management | Medium |
| `ReportAction.ts` — Chat/action history | Comment trail on reports | Medium |
| `Currency.ts` — Exchange rates | Multi-currency conversion | Medium |
| `ExpenseRule.ts` — Auto-categorization rules | Merchant → category rules | Medium |
| `ExportTemplate.ts` — CSV templates | Custom export formats | Low |
| `ReportLayout.ts` — Report column layout | Custom report views | Low |
| `Per_Diem_Rate__c` fields complete | Per diem sub-rates, time periods | Medium |

### Business Logic (src/libs/actions/)

| Original | What It Does | Priority |
|----------|--------------|----------|
| `IOU/Split.ts` — Split expenses | Split bills among users | Medium |
| `IOU/SendMoney.ts` — P2P payments | Send money between users | Low |
| `IOU/SendInvoice.ts` — Invoicing | Create and send invoices | Medium |
| `IOU/BulkEdit.ts` — Bulk updates | Bulk field changes on expenses | Medium |
| `IOU/Duplicate.ts` — Duplicate detection | Find and merge duplicates | High |
| `IOU/Receipt.ts` — Receipt management | Attach/replace/scan receipts | High |
| `IOU/PerDiem.ts` — Per diem creation | Full per diem expense flow | Medium |
| `IOU/MoneyRequest.ts` — Distance GPS | GPS tracking for mileage | Medium |
| `Report/index.ts` — Comments/chat | Add comments to reports | Medium |
| `Report/index.ts` — Export to CSV/PDF | Report data export | Medium |
| `Policy/ReportField.ts` — Custom fields | Custom report fields | Medium |
| `Policy/Rules.ts` — Coding rules | Auto-categorization rules | Medium |
| `Policy/PerDiem.ts` — Per diem config | Rate tables and config | Medium |
| `Workflow.ts` — Approval chains | Multi-level approval config | High |
| `TaxRate.ts` — Tax rate CRUD | Tax configuration | Medium |
| `Card.ts` — Card management | Freeze/unfreeze, limits | Low |
| `CompanyCards.ts` — Company cards | Card feed import | Low |
| `BankAccounts.ts` — Bank setup | Bank account onboarding | Low |
| `Domain.ts` — Domain admin | Enterprise domain management | Low |
| `Export.ts` — Data export | File export/download | Medium |
| `ImportTransactions.ts` — CSV import | Import expenses from CSV | High |
| `ImportSpreadsheet.ts` — Spreadsheet import | Category/tag/member import | Medium |
| `Subscription.ts` — Billing | Plan management | Low |
| `Travel.ts` — Travel booking | Spotnana integration | Low |
| `connections/*` — Accounting integrations | QBO, Xero, NetSuite, Sage | High |

### Pages / UI

| Original | What It Does | Priority |
|----------|--------------|----------|
| `iou/request/step/IOURequestStepScan` — Receipt scanning | Camera-based receipt capture | High |
| `iou/request/step/IOURequestStepDistance*` — Distance UI | Map-based distance tracking | Medium |
| `iou/SplitExpensePage.tsx` — Split bill | Split expense among users | Medium |
| `workspace/accounting/` — Accounting integrations | Connect QBO/Xero/NetSuite | High |
| `workspace/companyCards/` — Company cards | Card feed management | Medium |
| `workspace/expensifyCard/` — Expensify Card | Card issuance and management | Low |
| `workspace/workflows/` — Approval workflow builder | Visual approval chain config | High |
| `workspace/taxes/` — Tax management | Tax rate CRUD UI | Medium |
| `workspace/perDiem/` — Per diem management | Per diem rate tables | Medium |
| `workspace/rules/` — Policy rules | Merchant auto-categorization | Medium |
| `workspace/reports/` — Custom report fields | Report field config | Medium |
| `workspace/invoices/` — Invoicing | Invoice management | Medium |
| `settings/Wallet/` — Wallet/payments | Payment method management | Low |
| `settings/Security/` — 2FA/security | Security settings | Low |
| `settings/Subscription/` — Billing | Plan/subscription management | Low |
| `settings/Rules/` — Personal expense rules | User-level auto-rules | Medium |
| `Travel/` — Trip management | Booking and trip details | Low |
| `domain/` — Domain admin | Domain control panel | Low |
| `TransactionDuplicate/` — Duplicate review | Duplicate expense resolution | High |
| `TransactionMerge/` — Merge transactions | Merge duplicate expenses | High |
| `EnablePayments/` — KYC onboarding | Payment method setup | Low |
| `ReimbursementAccount/` — Bank onboarding | Business bank setup | Low |
| `MissingPersonalDetails/` — KYC details | Personal info collection | Low |

### Components (src/components/)

| Original | What It Does | Priority |
|----------|--------------|----------|
| `MoneyRequestConfirmationList/` — Confirmation | Full expense confirmation | Medium |
| `DistanceMapView/` + `MapView/` — Maps | Distance route visualization | Low |
| `Attachments/` — File viewer | Receipt/attachment viewing | High |
| `Search/` (~173 files) — Search UI | Advanced search autocomplete | Medium |
| `Charts/` — Data visualization | Spend analytics charts | Medium |
| `EmojiPicker/` — Reactions | Comment reactions | Low |
| `PlaidLink/` — Bank linking | Plaid integration | Low |
| `Onfido/` — Identity verification | KYC verification | Low |
| `ConnectTo*Flow/` — Accounting wizards | Integration setup wizards | High |

---

## 3. NOT NEEDED (Platform-handled or N/A for Salesforce)

### Platform Infrastructure (handled by Salesforce natively)

| Original | Why Not Needed |
|----------|----------------|
| `Session/` — Authentication | Salesforce Identity handles auth natively |
| `Pusher/` — WebSocket real-time | Platform Events + Streaming API |
| `Network/` — Offline queue | Salesforce Mobile handles offline |
| `PersistedRequests.ts` — Request persistence | Not needed — server-side platform |
| `OnyxUpdates.ts` / `OnyxUpdateManager/` | Salesforce handles data sync |
| `Reconnect.ts` — Auto-reconnect | Platform handles connectivity |
| `QueuedOnyxUpdates.ts` — Update queue | Not needed — server-side |
| `Middleware/` — Request middleware | Not needed — Apex handles directly |
| `API/` — Client API layer | `@AuraEnabled` methods replace this |
| `OnyxDerived/` — Derived state | SOQL queries and formula fields |
| `applyOnyxUpdatesReliably.ts` | Platform data consistency |
| `clearOnyxAndSeedFullReconnect.ts` | Not applicable |
| `FormActions.ts` — Form state | LWC reactive properties |
| `Modal.ts` — Modal state | LWC modal management |
| `Tab.ts` — Tab state | `lightning-tabset` handles this |

### React Native / Mobile-Specific

| Original | Why Not Needed |
|----------|----------------|
| `AppUpdate/` — App updates | Salesforce app updates automatically |
| `Attachment/index.native.ts` — Native cache | Files API handles storage |
| `CachedPDFPaths/` — PDF caching | Not needed on server |
| `Device/` — Device ID/info | Not needed — server-side |
| `InputFocus/` — Focus tracking | LWC handles focus natively |
| `StoreReview/` — App store review | Not applicable |
| `NavigationBar/` — Android nav bar | Not applicable |
| `MapboxToken.ts` — Map tokens | Not needed unless maps added |
| `CanvasSize.ts` — Canvas detection | Not applicable |
| `ContactPermissions.ts` — OS permissions | Not applicable |
| `UserLocation.ts` — GPS coordinates | Not needed unless GPS tracking added |
| `GPSDraftDetails.ts` — GPS drafts | Not needed unless GPS tracking added |
| `isGPSInProgressModalOpen.ts` | Not applicable |
| `HybridApp/` — OldDot/NewDot bridge | Not applicable |
| `Link.ts` — Deep linking | Salesforce handles URLs natively |
| `Download.ts` — Download state | Browser handles downloads |
| `EmojiPickerAction.ts` — Emoji popover | Not applicable |
| `MobileSelectionMode.ts` — Mobile select | Not applicable |
| `setFullscreenVisibility.ts` | Not applicable |
| `KeyboardShortcut/` — Global shortcuts | Not applicable |
| `Hoverable/` component | Not applicable |
| `SafeArea*/` components | Not applicable |
| `KeyboardAvoidingView/` | Not applicable |
| `NavigationDeferredMount.tsx` | Not applicable |

### Expensify-Specific Features Not Applicable to Salesforce Port

| Original | Why Not Needed |
|----------|----------------|
| `TeachersUnite/` — Teacher referral program | Expensify marketing program |
| `Chronos.ts` — Calendar OOO | Expensify-specific calendar |
| `ExitSurvey.ts` — Exit survey | Expensify churn survey |
| `Agent.ts` — AI agents | Expensify AI concierge |
| `Tour.ts` — Test drive demo | Expensify demo tour |
| `Share/` — OS share extension | Mobile share intent |
| `Onboarding*/` — Onboarding wizard | Salesforce has own setup flows |
| `TestTool.ts` / `Debug/` — Dev tools | Dev-only debugging |
| `SentryDebug.ts` — Sentry debug | Expensify monitoring |
| `StatsCounter.ts` — Graphite stats | Expensify telemetry |
| `ImportOnyxState.ts` — Debug import | Dev tool |
| `MaskOnyx.ts` — Privacy masking | Dev tool |
| `ActiveClients.ts` — Multi-tab tracking | Browser tab sync |
| `CurrentDate.ts` — Date tracking | Not needed |
| `RoomMembersUserSearchPhrase.ts` | Chat-specific UI state |
| `SplitExpenses.ts` — Navigation helper | Not needed — UI handled differently |
| `QuickActionNavigation.ts` — FAB routing | Not applicable |
| `ReportNavigation.ts` — Search state | Not applicable |
| `TransactionThreadNavigation.ts` | Chat thread nav |
| `SignInRedirect.ts` — Auth redirect | Salesforce handles this |
| `replaceOptimisticReportWithActualReport.ts` | Optimistic update infrastructure |
| `RequestConflictUtils.ts` — Conflict resolution | Server-side platform |
| `Passkey.ts` — WebAuthn | Salesforce MFA handles this |
| `VacationDelegate.ts` — Vacation delegate | Could use Salesforce delegated admin |
| `MergeAccounts.ts` — Account merge | Not applicable |
| `CloseAccount.ts` — Close account | Not applicable |
| `Delegate.ts` — Copilot access | Not applicable in same form |
| `ScheduleCall.ts` — Guide calls | Expensify support feature |
| `Help.ts` — Support page | Salesforce has own help system |
| `SidePanel.ts` — Side panel state | LWC layout handles this |
| `Wallet.ts` — Expensify Wallet KYC | Expensify-specific product |
| `PersonalCards.ts` — Personal card linking | Expensify-specific |
| `Plaid.ts` — Plaid flows | Would need separate integration |
| `TravelInvoicing.ts` — Travel invoicing | Spotnana-specific |
| `TwoFactorAuthActions.ts` — 2FA setup | Salesforce MFA native |

### Components Not Needed

| Original | Why Not Needed |
|----------|----------------|
| `ScreenWrapper/` | `lightning-card` / page layout |
| `HeaderWithBackButton/` | SLDS page header |
| `FocusTrap/` | Platform handles focus |
| `Composer/` — Chat composer | Chatter handles messaging |
| `HTMLEngineProvider/` — Chat HTML render | Chatter renders messages |
| `Reactions/` — Emoji reactions | Chatter likes/reactions |
| `LHNOptionsList/` — Left nav | Salesforce app navigation |
| `EmojiPicker/` | Not needed for expense app |
| `ReportActionItem/` — Chat actions | Chatter feed items |
| `FloatingActionButton.tsx` — FAB | Lightning quick actions |
| `Lottie*/` — Animations | Not needed |
| `MultiGestureCanvas/` — Pinch/zoom | Not needed |
| `DragAndDrop/` — Drag/drop | Not needed |
| `Lightbox/` — Image lightbox | File preview handles this |
| `VideoPlayer*/` — Video | Not needed |
| `TestDrive/` — Demo | Not needed |
| `QRCode.tsx` — QR generation | Not needed |
| All `*SkeletonView*` — Loading skeletons | `lightning-spinner` |
| `Breadcrumbs.tsx` | Salesforce native breadcrumbs |
| `ThemeProvider.tsx` | SLDS theming |
| `LocaleContextProvider.tsx` | Salesforce i18n/translation framework |

---

## Summary Counts

| Category | Count |
|----------|-------|
| **Ported** | ~45 features/modules |
| **Not Ported (relevant)** | ~65 features/modules |
| **Not Needed** | ~95+ features/modules |

### Priority Matrix for Remaining Work

| Priority | Features |
|----------|----------|
| **High** | Duplicate detection, receipt management, accounting integrations, CSV import, approval workflow builder, transaction merge |
| **Medium** | Split expenses, comments/chat on reports, invoicing, per diem, tax rates, distance tracking, custom report fields, policy rules, bulk edit, multi-currency, export |
| **Low** | Cards, banking, wallet, travel, domain admin, KYC, subscriptions, personal cards |
