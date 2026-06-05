# ExpensifySF

Salesforce-native expense management port. All application metadata, Apex, LWC, and tests live under [`salesforce-port/`](salesforce-port/).

## Documentation

| Doc | Purpose |
|-----|---------|
| [`salesforce-port/PORTING_PLAN.md`](salesforce-port/PORTING_PLAN.md) | Architecture and mapping from Expensify concepts |
| [`salesforce-port/MIGRATION_TRACKER.md`](salesforce-port/MIGRATION_TRACKER.md) | Feature waves and deletion gate status |
| [`salesforce-port/SRC_AUDIT.md`](salesforce-port/SRC_AUDIT.md) | React Native source audit (historical reference) |
| [`salesforce-port/FEATURE_AUDIT.md`](salesforce-port/FEATURE_AUDIT.md) | Feature parity matrix |

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- Dev Hub enabled (for scratch orgs)
- Node.js optional (CLI only)

## Windows clone note

If cloning on Windows, enable long paths:

```powershell
git config --global core.longpaths true
```

Or use [`scripts/clone-repo.ps1`](scripts/clone-repo.ps1).

## Scratch org setup

```powershell
cd salesforce-port
sf org login web --set-default-dev-hub --alias devOrg
sf org create scratch --definition-file config/project-scratch-def.json --alias expensify-sf --duration-days 7 --set-default
sf org assign permset --name Expense_Admin --target-org expensify-sf
```

Assign admin FLS for tests (scratch org admin user):

```powershell
sf apex run --file scripts/assign-expense-admin.apex --target-org expensify-sf
```

## Deploy

```powershell
cd salesforce-port
sf project deploy start --source-dir force-app/main/default --target-org expensify-sf --test-level NoTestRun --ignore-conflicts
```

Validate before release:

```powershell
sf project deploy validate --source-dir force-app/main/default --target-org expensify-sf --test-level RunLocalTests --wait 30
```

## Tests

```powershell
cd salesforce-port
sf apex run test --target-org expensify-sf --code-coverage --result-format human --wait 30
```

## Permission sets

| Set | Audience |
|-----|----------|
| `Expense_User` | Submitters |
| `Expense_Approver` | Approvers |
| `Expense_Admin` | Workspace admins |

Assign via **Setup → Permission Set Assignments** or `sf org assign permset`.

## App

After deploy, open the **Expensify Expense Management** Lightning app and assign permission sets to users.
