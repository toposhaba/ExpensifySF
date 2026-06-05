public with sharing class ApprovalWorkflowService {

    public class WorkflowException extends Exception {}

    public class ApproverResolution {
        @AuraEnabled
        public Boolean hasApprover;
        @AuraEnabled
        public Id approverId;
        @AuraEnabled
        public String approverName;
        @AuraEnabled
        public Id stepId;
        @AuraEnabled
        public Decimal stepOrder;
        @AuraEnabled
        public Decimal approvalLimit;
        @AuraEnabled
        public Boolean routedByOverride;
    }

    public static List<Approval_Chain__c> getSteps(Id policyId) {
        if (policyId == null) {
            throw new WorkflowException('Policy is required');
        }
        return [
            SELECT Id, Policy__c, Approver__c, Approver__r.Name, Order__c,
                   Approval_Limit__c, Is_Active__c, Submits_To_Override__c,
                   Submits_To_Override__r.Name
            FROM Approval_Chain__c
            WHERE Policy__c = :policyId
            WITH USER_MODE
            ORDER BY Order__c ASC NULLS LAST
        ];
    }

    public static Approval_Chain__c addStep(Id policyId, Id approverId, Decimal approvalLimit, Id submitsToOverride) {
        if (policyId == null) {
            throw new WorkflowException('Policy is required');
        }
        if (approverId == null) {
            throw new WorkflowException('Approver is required');
        }

        Approval_Chain__c step = new Approval_Chain__c(
            Policy__c = policyId,
            Approver__c = approverId,
            Order__c = getNextOrder(policyId),
            Approval_Limit__c = approvalLimit,
            Submits_To_Override__c = submitsToOverride,
            Is_Active__c = true
        );
        insert as user step;
        return step;
    }

    public static Approval_Chain__c updateStep(Id stepId, Id approverId, Decimal approvalLimit, Id submitsToOverride, Boolean isActive) {
        if (stepId == null) {
            throw new WorkflowException('Step is required');
        }

        Approval_Chain__c step = new Approval_Chain__c(Id = stepId);
        if (approverId != null) {
            step.Approver__c = approverId;
        }
        step.Approval_Limit__c = approvalLimit;
        step.Submits_To_Override__c = submitsToOverride;
        if (isActive != null) {
            step.Is_Active__c = isActive;
        }
        update as user step;
        return step;
    }

    public static void removeStep(Id stepId) {
        if (stepId == null) {
            throw new WorkflowException('Step is required');
        }

        List<Approval_Chain__c> steps = [
            SELECT Id, Policy__c
            FROM Approval_Chain__c
            WHERE Id = :stepId
            WITH USER_MODE
            LIMIT 1
        ];
        if (steps.isEmpty()) {
            throw new WorkflowException('Step not found');
        }

        Id policyId = steps[0].Policy__c;
        delete as user steps;
        resequence(policyId);
    }

    public static void reorderSteps(Id policyId, List<Id> orderedStepIds) {
        if (policyId == null) {
            throw new WorkflowException('Policy is required');
        }
        if (orderedStepIds == null || orderedStepIds.isEmpty()) {
            return;
        }

        Set<Id> existingIds = new Map<Id, Approval_Chain__c>(getSteps(policyId)).keySet();

        List<Approval_Chain__c> toUpdate = new List<Approval_Chain__c>();
        Integer order = 1;
        for (Id stepId : orderedStepIds) {
            if (existingIds.contains(stepId)) {
                toUpdate.add(new Approval_Chain__c(Id = stepId, Order__c = order));
                order++;
            }
        }
        if (!toUpdate.isEmpty()) {
            update as user toUpdate;
        }
    }

    public static ApproverResolution resolveNextApprover(Id policyId, Decimal amount, Id currentApproverId) {
        ApproverResolution result = new ApproverResolution();
        result.hasApprover = false;
        result.routedByOverride = false;

        if (policyId == null) {
            return result;
        }

        List<Approval_Chain__c> activeSteps = new List<Approval_Chain__c>();
        for (Approval_Chain__c step : getSteps(policyId)) {
            if (step.Is_Active__c == true) {
                activeSteps.add(step);
            }
        }
        if (activeSteps.isEmpty()) {
            return result;
        }

        Integer startIndex = 0;
        if (currentApproverId != null) {
            startIndex = activeSteps.size();
            for (Integer i = 0; i < activeSteps.size(); i++) {
                if (activeSteps[i].Approver__c == currentApproverId) {
                    startIndex = i + 1;
                    break;
                }
            }
        }

        for (Integer i = startIndex; i < activeSteps.size(); i++) {
            Approval_Chain__c step = activeSteps[i];
            Boolean withinLimit = step.Approval_Limit__c == null || amount == null || amount <= step.Approval_Limit__c;

            if (withinLimit) {
                result.hasApprover = true;
                result.approverId = step.Approver__c;
                result.approverName = step.Approver__r != null ? step.Approver__r.Name : null;
                result.stepId = step.Id;
                result.stepOrder = step.Order__c;
                result.approvalLimit = step.Approval_Limit__c;
                return result;
            }

            if (step.Submits_To_Override__c != null) {
                result.hasApprover = true;
                result.approverId = step.Submits_To_Override__c;
                result.approverName = step.Submits_To_Override__r != null ? step.Submits_To_Override__r.Name : null;
                result.stepId = step.Id;
                result.stepOrder = step.Order__c;
                result.approvalLimit = step.Approval_Limit__c;
                result.routedByOverride = true;
                return result;
            }
        }

        return result;
    }

    public static ApproverResolution resolveNextApproverForReport(Id reportId) {
        if (reportId == null) {
            throw new WorkflowException('Report is required');
        }

        List<Expense_Report__c> reports = [
            SELECT Id, Policy__c, Total_Amount__c, Approver__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            WITH USER_MODE
            LIMIT 1
        ];
        if (reports.isEmpty()) {
            throw new WorkflowException('Report not found');
        }

        Expense_Report__c report = reports[0];
        return resolveNextApprover(report.Policy__c, report.Total_Amount__c, report.Approver__c);
    }

    private static Integer getNextOrder(Id policyId) {
        List<AggregateResult> results = [
            SELECT MAX(Order__c) maxOrder
            FROM Approval_Chain__c
            WHERE Policy__c = :policyId
            WITH USER_MODE
        ];
        if (results.isEmpty() || results[0].get('maxOrder') == null) {
            return 1;
        }
        Decimal maxOrder = Decimal.valueOf(String.valueOf(results[0].get('maxOrder')));
        return maxOrder.intValue() + 1;
    }

    private static void resequence(Id policyId) {
        List<Approval_Chain__c> steps = [
            SELECT Id, Order__c
            FROM Approval_Chain__c
            WHERE Policy__c = :policyId
            WITH USER_MODE
            ORDER BY Order__c ASC NULLS LAST
        ];
        List<Approval_Chain__c> toUpdate = new List<Approval_Chain__c>();
        Integer order = 1;
        for (Approval_Chain__c step : steps) {
            if (step.Order__c != order) {
                toUpdate.add(new Approval_Chain__c(Id = step.Id, Order__c = order));
            }
            order++;
        }
        if (!toUpdate.isEmpty()) {
            update as user toUpdate;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Approval_Chain__c> getApprovalSteps(Id policyId) {
        return getSteps(policyId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Policy_Member__c> getApproverOptions(Id policyId) {
        if (policyId == null) {
            throw new WorkflowException('Policy is required');
        }
        return [
            SELECT Id, User__c, User__r.Name, User__r.Email, Role__c
            FROM Policy_Member__c
            WHERE Policy__c = :policyId
            WITH USER_MODE
            ORDER BY User__r.Name
        ];
    }

    @AuraEnabled
    public static Approval_Chain__c addApprovalStep(Id policyId, Id approverId, Decimal approvalLimit, Id submitsToOverride) {
        return addStep(policyId, approverId, approvalLimit, submitsToOverride);
    }

    @AuraEnabled
    public static Approval_Chain__c updateApprovalStep(Id stepId, Id approverId, Decimal approvalLimit, Id submitsToOverride, Boolean isActive) {
        return updateStep(stepId, approverId, approvalLimit, submitsToOverride, isActive);
    }

    @AuraEnabled
    public static void removeApprovalStep(Id stepId) {
        removeStep(stepId);
    }

    @AuraEnabled
    public static void reorderApprovalSteps(Id policyId, List<Id> orderedStepIds) {
        reorderSteps(policyId, orderedStepIds);
    }

    @AuraEnabled
    public static ApproverResolution resolveApproverForReport(Id reportId) {
        return resolveNextApproverForReport(reportId);
    }
}
