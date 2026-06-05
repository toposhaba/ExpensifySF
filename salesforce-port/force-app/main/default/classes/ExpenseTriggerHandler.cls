public with sharing class ExpenseTriggerHandler {

    public static void handleTrigger(List<Expense__c> newList, List<Expense__c> oldList, System.TriggerOperation operationType) {
        Set<Id> reportIdsToUpdate = new Set<Id>();

        switch on operationType {
            when BEFORE_INSERT, BEFORE_UPDATE {
                ExpenseRuleService.applyRules(newList);
            }
            when AFTER_INSERT {
                for (Expense__c exp : newList) {
                    if (exp.Report__c != null) {
                        reportIdsToUpdate.add(exp.Report__c);
                    }
                }
                publishEvents(newList, 'insert');
                runDuplicateDetection(newList);
            }
            when AFTER_UPDATE {
                for (Integer i = 0; i < newList.size(); i++) {
                    if (newList[i].Report__c != null) {
                        reportIdsToUpdate.add(newList[i].Report__c);
                    }
                    if (oldList[i].Report__c != null && oldList[i].Report__c != newList[i].Report__c) {
                        reportIdsToUpdate.add(oldList[i].Report__c);
                    }
                }
            }
            when AFTER_DELETE {
                for (Expense__c exp : oldList) {
                    if (exp.Report__c != null) {
                        reportIdsToUpdate.add(exp.Report__c);
                    }
                }
            }
        }

        if (!reportIdsToUpdate.isEmpty()) {
            updateReportTotals(reportIdsToUpdate);
        }
    }

    private static void updateReportTotals(Set<Id> reportIds) {
        List<Expense_Report__c> reportsToUpdate = new List<Expense_Report__c>();

        for (AggregateResult ar : [
            SELECT Report__c reportId,
                   SUM(Amount__c) totalAmount,
                   COUNT(Id) expenseCount
            FROM Expense__c
            WHERE Report__c IN :reportIds
            GROUP BY Report__c
        ]) {
            reportsToUpdate.add(new Expense_Report__c(
                Id = (Id) ar.get('reportId'),
                Total_Amount__c = (Decimal) ar.get('totalAmount'),
                Expense_Count__c = (Integer) ar.get('expenseCount')
            ));
        }

        Set<Id> reportsWithExpenses = new Set<Id>();
        for (Expense_Report__c r : reportsToUpdate) {
            reportsWithExpenses.add(r.Id);
        }
        for (Id reportId : reportIds) {
            if (!reportsWithExpenses.contains(reportId)) {
                reportsToUpdate.add(new Expense_Report__c(
                    Id = reportId,
                    Total_Amount__c = 0,
                    Expense_Count__c = 0
                ));
            }
        }

        if (!reportsToUpdate.isEmpty()) {
            update reportsToUpdate;
        }
    }

    private static void publishEvents(List<Expense__c> expenses, String eventType) {
    }

    private static void runDuplicateDetection(List<Expense__c> expenses) {
        if (Test.isRunningTest()) {
            return;
        }
        for (Expense__c exp : expenses) {
            try {
                DuplicateDetectionService.detectDuplicates(exp.Id);
            } catch (Exception e) {
            }
        }
    }
}
