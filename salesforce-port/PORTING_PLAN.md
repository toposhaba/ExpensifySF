# Expensify to Salesforce Porting Plan

## Executive Summary

This document provides a comprehensive plan for porting the Expensify App's expense management functionality to Salesforce using native platform capabilities: Custom Objects, Apex, Lightning Web Components (LWC), Flows, Permission Sets, and Platform Events.

---

## 1. Feature Catalog & Salesforce Mapping

### 1.1 Expense Management (Core)

| Expensify Feature | Salesforce Native Equivalent |
|---|---|
| Expense creation (manual) | LWC form + Apex controller + Custom Object |
| Receipt scanning (SmartScan) | Files API + External Service callout (OCR) |
| Distance tracking | Custom Object with waypoints + Google Maps API callout |
| Per diem expenses | Custom Object with rate lookup |
| Split expenses | Junction object (Expense_Split__c) |
| Expense categories | Custom Object (Expense_Category__c) with picklist values |
| Tags | Custom Object (Expense_Tag__c) with multi-select |
| Tax calculation | Custom metadata + Apex tax engine |
| Billable/reimbursable flags | Checkbox fields on Expense__c |
| Duplicate detection | Apex trigger + matching rules |
| Bulk edit | LWC datatable with inline editing |
| Hold/reject expenses | Status field + approval actions |

### 1.2 Report & Approval Workflow

| Expensify Feature | Salesforce Native Equivalent |
|---|---|
| Expense report creation | Custom Object (Expense_Report__c) |
| Report submission | Approval Process + Flow |
| Multi-level approval | Approval Process with dynamic routing |
| Auto-approval rules | Flow + Process Builder criteria |
| Report export (CSV/PDF) | Apex + Visualforce PDF rendering |
| Report custom fields | Custom fields on Expense_Report__c |
| Spend limits/violations | Validation Rules + Apex trigger |

### 1.3 Workspace / Policy Management

| Expensify Feature | Salesforce Native Equivalent |
|---|---|
| Workspace (Policy) | Custom Object (Expense_Policy__c) |
| Member management | Junction object (Policy_Member__c) |
| Role-based access | Permission Sets + Custom Permissions |
| Expense rules | Custom Metadata Type (Expense_Rule__mdt) |
| Approval chains | Custom Object (Approval_Chain__c) |
| Category/tag config per workspace | Related lists on Policy |
| Distance rates | Custom Object (Distance_Rate__c) |
| Per diem rates | Custom Object (Per_Diem_Rate__c) |
| Auto-reporting/scheduled submit | Scheduled Flow |

### 1.4 Payment & Reimbursement

| Expensify Feature | Salesforce Native Equivalent |
|---|---|
| Bank account linking | Custom Object (Bank_Account__c) + encrypted fields |
| Payment processing | External Service callout (payment gateway) |
| Wallet/balance | Custom Object (Wallet__c) |
| Reimbursement tracking | Status field on Expense_Report__c + Payment__c object |

### 1.5 Search & Reporting

| Expensify Feature | Salesforce Native Equivalent |
|---|---|
| Advanced search | SOSL + LWC search component |
| Saved searches | Custom Object (Saved_Search__c) |
| Bulk operations | LWC datatable + Apex batch |
| Dashboards/analytics | Salesforce Reports & Dashboards (native) |
| Spend charts | LWC chart components + Report Charts |

### 1.6 Communication & Collaboration

| Expensify Feature | Salesforce Native Equivalent |
|---|---|
| Chat/comments on reports | Chatter (FeedItem on record) |
| Task assignment | Salesforce Tasks (standard object) |
| Notifications | Custom Notifications + Platform Events |
| @mentions | Chatter mentions (native) |
| Private notes | Custom Object or Rich Text field |

### 1.7 Accounting Integrations

| Expensify Feature | Salesforce Native Equivalent |
|---|---|
| QuickBooks Online | Named Credential + External Service |
| Xero | Named Credential + External Service |
| NetSuite | Named Credential + External Service |
| Sage Intacct | Named Credential + External Service |
| GL code mapping | Custom Metadata Type |
| Auto-sync | Scheduled Flow + Platform Events |

### 1.8 Authentication & Security

| Expensify Feature | Salesforce Native Equivalent |
|---|---|
| User authentication | Salesforce Identity (built-in) |
| SSO/SAML | Salesforce SSO (native) |
| 2FA | Salesforce MFA (native) |
| Role-based permissions | Profiles + Permission Sets + Custom Permissions |
| Field-level security | FLS (native) |
| Record ownership | OWD + Sharing Rules |

---

## 2. Data Schema Design

### 2.1 Custom Objects

| Object API Name | Purpose | Key Fields |
|---|---|---|
| `Expense_Policy__c` | Workspace/organization config | Name, Owner, Currency, Type, Approval_Mode |
| `Policy_Member__c` | Junction: User ↔ Policy | Policy (lookup), User (lookup), Role (picklist) |
| `Expense_Report__c` | Groups expenses for submission | Policy (lookup), Owner, Status, Total, Currency |
| `Expense__c` | Individual expense/transaction | Report (lookup), Amount, Currency, Merchant, Date, Category, Tag |
| `Expense_Category__c` | Expense categorization | Policy (lookup), Name, GL_Code, Enabled, Max_Amount |
| `Expense_Tag__c` | Expense tagging | Policy (lookup), Name, GL_Code, Enabled |
| `Expense_Violation__c` | Policy violation tracking | Expense (lookup), Type, Message, Severity |
| `Distance_Rate__c` | Mileage rate config | Policy (lookup), Currency, Rate_Per_Unit, Unit |
| `Per_Diem_Rate__c` | Per diem rate config | Policy (lookup), Destination, Daily_Rate, Currency |
| `Approval_Chain__c` | Approval workflow config | Policy (lookup), Approver (lookup), Order, Limit |
| `Payment__c` | Reimbursement payment tracking | Report (lookup), Amount, Method, Status, Date |
| `Expense_Receipt__c` | Receipt file metadata | Expense (lookup), File_URL, Scan_Status |
| `Saved_Search__c` | User saved search queries | Owner, Query, Name |
| `Expense_Split__c` | Split expense junction | Parent_Expense (lookup), Child_Expense (lookup), Amount |
| `Expense_Comment__c` | Comments on expenses/reports | Parent (polymorphic), Author, Body, Created_Date |

### 2.2 Custom Metadata Types

| Metadata API Name | Purpose |
|---|---|
| `Expense_Rule__mdt` | Configurable expense rules (limits, requirements) |
| `Tax_Rate__mdt` | Tax rate configurations |
| `Currency_Rate__mdt` | Exchange rate lookups |
| `Integration_Mapping__mdt` | GL code and accounting field mappings |

### 2.3 Platform Events

| Event API Name | Purpose |
|---|---|
| `Expense_Submitted__e` | Fired when expense report is submitted |
| `Expense_Approved__e` | Fired when expense report is approved |
| `Expense_Rejected__e` | Fired when expense is rejected |
| `Payment_Processed__e` | Fired when reimbursement is processed |

---

## 3. UI Components (Lightning Web Components)

### 3.1 App Shell
- `expenseApp` — Main application container with navigation
- `expenseNavigation` — Tab-based navigation (Home, Expenses, Reports, Workspaces, Settings)

### 3.2 Expense Components
- `expenseList` — Datatable showing expenses with bulk actions
- `expenseForm` — Create/edit expense form
- `expenseCard` — Individual expense display card
- `receiptUploader` — File upload with preview
- `expenseSearch` — Advanced search with filters
- `expenseSplitModal` — Split expense UI
- `distanceExpenseForm` — Distance/mileage expense entry
- `perDiemForm` — Per diem expense entry

### 3.3 Report Components
- `expenseReportList` — List of expense reports
- `expenseReportDetail` — Report detail with transactions
- `reportSubmitButton` — Submit for approval
- `reportApprovalActions` — Approve/reject/hold actions
- `reportExport` — Export to CSV/PDF

### 3.4 Workspace Components
- `workspaceList` — List of workspaces
- `workspaceSettings` — Workspace configuration
- `workspaceMembers` — Member management
- `categoryManager` — Category CRUD
- `tagManager` — Tag CRUD
- `approvalWorkflow` — Visual approval chain builder

### 3.5 Dashboard Components
- `spendOverview` — Spend summary cards
- `spendByCategory` — Category breakdown chart
- `recentExpenses` — Recent activity feed
- `pendingApprovals` — Items awaiting action

---

## 4. UX Flows

### 4.1 Expense Creation Flow
1. User clicks "New Expense" → `expenseForm` LWC opens
2. User enters amount, merchant, date, category, tag
3. User optionally uploads receipt → File stored via ContentVersion
4. System validates against policy rules (Apex trigger)
5. Violations flagged if limits exceeded
6. Expense saved to `Expense__c`
7. User assigns to report or system auto-assigns

### 4.2 Report Submission & Approval Flow
1. User reviews expenses in `expenseReportDetail`
2. User clicks Submit → Approval Process initiated
3. Approver receives notification (Custom Notification)
4. Approver views report → Approve/Reject/Hold
5. If multi-level: routes to next approver
6. On final approval: status = Approved, Payment__c created
7. Finance processes reimbursement

### 4.3 Workspace Management Flow
1. Admin creates workspace → `Expense_Policy__c` record
2. Admin configures categories, tags, rates
3. Admin invites members → `Policy_Member__c` records
4. Admin sets approval chains → `Approval_Chain__c` records
5. Members see workspace policies applied to their expenses

### 4.4 Search & Bulk Operations Flow
1. User enters search criteria in `expenseSearch`
2. SOSL/SOQL returns matching records
3. User selects multiple records
4. Bulk action (approve, reject, categorize, export)
5. Apex batch processes selected records

---

## 5. Test Strategy

### 5.1 Unit Tests (Apex)
- `ExpenseServiceTest` — Expense CRUD operations
- `ExpenseReportServiceTest` — Report creation, submission
- `ApprovalServiceTest` — Approval routing, multi-level
- `PolicyServiceTest` — Policy CRUD, member management
- `ViolationServiceTest` — Rule engine, limit checks
- `PaymentServiceTest` — Reimbursement processing
- `SearchServiceTest` — Search query building
- `TriggerHandlerTest` — All trigger handlers

### 5.2 Integration Tests
- Approval Process end-to-end
- Platform Event publishing and handling
- File upload and receipt processing
- External service callouts (mock)

### 5.3 LWC Tests (Jest)
- Component rendering
- User interaction (form submission, button clicks)
- Wire adapter mocking
- Error state handling

---

## 6. Security Model

### 6.1 Object-Level Security
| Object | OWD | Sharing |
|---|---|---|
| Expense__c | Private | Criteria-based (Policy membership) |
| Expense_Report__c | Private | Criteria-based (Policy membership + Approver) |
| Expense_Policy__c | Public Read | Admin = Read/Write |
| Policy_Member__c | Controlled by Parent | Inherits from Policy |

### 6.2 Permission Sets
| Permission Set | Access |
|---|---|
| Expense_User | Create/Read expenses and reports |
| Expense_Approver | Expense_User + Approve/Reject |
| Expense_Admin | Full CRUD on all expense objects |
| Policy_Admin | Full CRUD on policies and configuration |
| Finance_Admin | Payment processing + export |

### 6.3 Custom Permissions
| Permission | Gates |
|---|---|
| Can_Submit_Reports | Report submission |
| Can_Approve_Reports | Approval actions |
| Can_Process_Payments | Reimbursement |
| Can_Manage_Policy | Workspace admin |
| Can_Export_Data | Data export |

---

## 7. Implementation Phases

### Phase 1: Foundation (Current Build)
- Custom Objects & Schema
- Core Apex Services (Expense CRUD, Report CRUD)
- Basic LWC components (list, form, detail)
- Permission Sets & Security
- Unit Tests (75%+ coverage)

### Phase 2: Workflow & Automation
- Approval Processes
- Flow-based automation (scheduled submit, auto-categorize)
- Platform Events
- Notification framework

### Phase 3: Advanced Features
- Receipt scanning integration
- Accounting system connectors
- Advanced search with SOSL
- Dashboard & reporting
- Bulk operations

### Phase 4: Polish & Integration
- Mobile-optimized LWCs
- Offline support (Salesforce Mobile)
- Custom notifications
- Performance optimization
