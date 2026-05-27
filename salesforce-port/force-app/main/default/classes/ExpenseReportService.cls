public with sharing class ExpenseReportService {

    public static Expense_Report__c createReport(Expense_Report__c report) {
        if (report.Status__c == null) {
            report.Status__c = 'Open';
        }
        if (report.Currency__c == null) {
            report.Currency__c = 'USD';
        }
        insert report;
        return report;
    }

    public static Expense_Report__c getReport(Id reportId) {
        return [
            SELECT Id, Name, Status__c, Total_Amount__c, Currency__c, Policy__c,
                   Policy__r.Name, Submitted_Date__c, Approved_Date__c, Approver__c,
                   Approver__r.Name, Description__c, Reimbursable_Total__c,
                   Expense_Count__c, OwnerId, Owner.Name, CreatedDate
            FROM Expense_Report__c
            WHERE Id = :reportId
            LIMIT 1
        ];
    }

    public static List<Expense_Report__c> getReportsByUser(Id userId) {
        return [
            SELECT Id, Name, Status__c, Total_Amount__c, Currency__c, Policy__c,
                   Policy__r.Name, Submitted_Date__c, Expense_Count__c, CreatedDate
            FROM Expense_Report__c
            WHERE OwnerId = :userId
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    public static List<Expense_Report__c> getReportsToApprove(Id approverId) {
        return [
            SELECT Id, Name, Status__c, Total_Amount__c, Currency__c, Policy__c,
                   Policy__r.Name, Submitted_Date__c, Expense_Count__c,
                   OwnerId, Owner.Name, CreatedDate
            FROM Expense_Report__c
            WHERE Approver__c = :approverId AND Status__c = 'Submitted'
            ORDER BY Submitted_Date__c ASC
        ];
    }

    public static Expense_Report__c submitReport(Id reportId) {
        Expense_Report__c report = [
            SELECT Id, Status__c, OwnerId, Policy__c, Total_Amount__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            LIMIT 1
        ];

        if (report.Status__c != 'Open' && report.Status__c != 'Rejected') {
            throw new ReportException('Only open or rejected reports can be submitted');
        }

        List<Expense__c> expenses = [
            SELECT Id FROM Expense__c WHERE Report__c = :reportId
        ];
        if (expenses.isEmpty()) {
            throw new ReportException('Cannot submit a report with no expenses');
        }

        List<Expense_Violation__c> violations = [
            SELECT Id FROM Expense_Violation__c
            WHERE Expense__c IN (SELECT Id FROM Expense__c WHERE Report__c = :reportId)
        ];

        Id approverId = getApprover(report);

        report.Status__c = 'Submitted';
        report.Submitted_Date__c = Datetime.now();
        report.Approver__c = approverId;
        update report;

        updateExpenseStatuses(reportId, 'Pending');

        if (report.Policy__c != null) {
            Expense_Policy__c policy = [
                SELECT Auto_Approve_Limit__c FROM Expense_Policy__c WHERE Id = :report.Policy__c LIMIT 1
            ];
            if (policy.Auto_Approve_Limit__c != null
                && report.Total_Amount__c <= policy.Auto_Approve_Limit__c
                && violations.isEmpty()) {
                approveReport(reportId);
            }
        }

        return report;
    }

    public static Expense_Report__c approveReport(Id reportId) {
        Expense_Report__c report = [
            SELECT Id, Status__c FROM Expense_Report__c WHERE Id = :reportId LIMIT 1
        ];

        if (report.Status__c != 'Submitted') {
            throw new ReportException('Only submitted reports can be approved');
        }

        report.Status__c = 'Approved';
        report.Approved_Date__c = Datetime.now();
        update report;

        updateExpenseStatuses(reportId, 'Approved');

        return report;
    }

    public static Expense_Report__c rejectReport(Id reportId, String reason) {
        Expense_Report__c report = [
            SELECT Id, Status__c FROM Expense_Report__c WHERE Id = :reportId LIMIT 1
        ];

        if (report.Status__c != 'Submitted') {
            throw new ReportException('Only submitted reports can be rejected');
        }

        report.Status__c = 'Rejected';
        report.Description__c = reason;
        update report;

        updateExpenseStatuses(reportId, 'Rejected');

        return report;
    }

    public static Expense_Report__c reopenReport(Id reportId) {
        Expense_Report__c report = new Expense_Report__c(
            Id = reportId,
            Status__c = 'Open',
            Submitted_Date__c = null,
            Approved_Date__c = null
        );
        update report;
        updateExpenseStatuses(reportId, 'Draft');
        return report;
    }

    public static void markReimbursed(Id reportId) {
        Expense_Report__c report = [
            SELECT Id, Status__c FROM Expense_Report__c WHERE Id = :reportId LIMIT 1
        ];

        if (report.Status__c != 'Approved') {
            throw new ReportException('Only approved reports can be marked as reimbursed');
        }

        report.Status__c = 'Reimbursed';
        update report;
    }

    private static Id getApprover(Expense_Report__c report) {
        if (report.Policy__c == null) {
            return null;
        }

        List<Policy_Member__c> members = [
            SELECT Submits_To__c
            FROM Policy_Member__c
            WHERE Policy__c = :report.Policy__c AND User__c = :report.OwnerId
            LIMIT 1
        ];

        if (!members.isEmpty() && members[0].Submits_To__c != null) {
            return members[0].Submits_To__c;
        }

        List<Approval_Chain__c> chains = [
            SELECT Approver__c
            FROM Approval_Chain__c
            WHERE Policy__c = :report.Policy__c
            ORDER BY Order__c ASC
            LIMIT 1
        ];

        if (!chains.isEmpty()) {
            return chains[0].Approver__c;
        }

        return null;
    }

    private static void updateExpenseStatuses(Id reportId, String status) {
        List<Expense__c> expenses = [
            SELECT Id FROM Expense__c WHERE Report__c = :reportId
        ];
        for (Expense__c exp : expenses) {
            exp.Status__c = status;
        }
        if (!expenses.isEmpty()) {
            update expenses;
        }
    }

    public class ReportException extends Exception {}
}
