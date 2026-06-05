public with sharing class InvocableResolveApprover {

    @InvocableMethod(label='Resolve Next Approver' description='Resolves the next approver for a report based on the policy approval chain and report amount' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                ApprovalWorkflowService.ApproverResolution resolution;
                if (req.reportId != null) {
                    resolution = ApprovalWorkflowService.resolveNextApproverForReport(req.reportId);
                } else {
                    resolution = ApprovalWorkflowService.resolveNextApprover(req.policyId, req.amount, req.currentApproverId);
                }
                res.hasApprover = resolution.hasApprover;
                res.approverId = resolution.approverId;
                res.approverName = resolution.approverName;
                res.stepId = resolution.stepId;
                res.approvalLimit = resolution.approvalLimit;
                res.routedByOverride = resolution.routedByOverride;
                res.isSuccess = true;
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
            }
            responseList.add(res);
        }
        return responseList;
    }

    public class Request {
        @InvocableVariable(label='Report Id' required=false)
        public Id reportId;

        @InvocableVariable(label='Policy Id' required=false)
        public Id policyId;

        @InvocableVariable(label='Amount' required=false)
        public Decimal amount;

        @InvocableVariable(label='Current Approver Id' required=false)
        public Id currentApproverId;
    }

    public class Results {
        @InvocableVariable(label='Has Approver')
        public Boolean hasApprover;

        @InvocableVariable(label='Approver Id')
        public Id approverId;

        @InvocableVariable(label='Approver Name')
        public String approverName;

        @InvocableVariable(label='Step Id')
        public Id stepId;

        @InvocableVariable(label='Approval Limit')
        public Decimal approvalLimit;

        @InvocableVariable(label='Routed By Override')
        public Boolean routedByOverride;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
