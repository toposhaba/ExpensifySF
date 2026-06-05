@isTest
private class ApprovalWorkflowServiceTest {

    private static User buildUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = alias + System.currentTimeMillis() + String.valueOf(Math.round(Math.random() * 100000));
        return new User(
            Alias = alias.left(8),
            Email = uniq + '@example.com',
            Username = uniq + '@example.com.invalid',
            LastName = 'WfApprover',
            FirstName = alias,
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }

    @TestSetup
    static void setupData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Workflow Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate',
            Approval_Mode__c = 'Advanced'
        );
        insert policy;

        List<User> approvers = new List<User>{
            buildUser('apr1'),
            buildUser('apr2'),
            buildUser('apr3')
        };
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert approvers;

            List<Policy_Member__c> members = new List<Policy_Member__c>();
            for (User u : approvers) {
                members.add(new Policy_Member__c(Policy__c = policy.Id, User__c = u.Id, Role__c = 'Approver'));
            }
            insert members;
        }
    }

    private static Expense_Policy__c getPolicy() {
        return [SELECT Id FROM Expense_Policy__c WHERE Name = 'Workflow Policy' LIMIT 1];
    }

    private static List<User> getApprovers() {
        return [SELECT Id, Name FROM User WHERE LastName = 'WfApprover' ORDER BY FirstName ASC];
    }

    @isTest
    static void testAddAndGetStepsOrdered() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();

        Test.startTest();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 100, null);
        ApprovalWorkflowService.addStep(policy.Id, approvers[1].Id, 500, null);
        ApprovalWorkflowService.addStep(policy.Id, approvers[2].Id, null, null);
        Test.stopTest();

        List<Approval_Chain__c> steps = ApprovalWorkflowService.getSteps(policy.Id);
        System.assertEquals(3, steps.size());
        System.assertEquals(1, steps[0].Order__c);
        System.assertEquals(2, steps[1].Order__c);
        System.assertEquals(3, steps[2].Order__c);
        System.assertEquals(approvers[0].Id, steps[0].Approver__c);
    }

    @isTest
    static void testAddStepValidation() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();

        Test.startTest();
        try {
            ApprovalWorkflowService.addStep(null, approvers[0].Id, 100, null);
            System.assert(false, 'Should throw for missing policy');
        } catch (ApprovalWorkflowService.WorkflowException e) {
            System.assert(e.getMessage().contains('Policy'));
        }

        try {
            ApprovalWorkflowService.addStep(policy.Id, null, 100, null);
            System.assert(false, 'Should throw for missing approver');
        } catch (ApprovalWorkflowService.WorkflowException e) {
            System.assert(e.getMessage().contains('Approver'));
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateStep() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        Approval_Chain__c step = ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 100, null);

        Test.startTest();
        ApprovalWorkflowService.updateStep(step.Id, approvers[1].Id, 250, approvers[2].Id, false);
        Test.stopTest();

        Approval_Chain__c saved = [
            SELECT Approver__c, Approval_Limit__c, Submits_To_Override__c, Is_Active__c
            FROM Approval_Chain__c WHERE Id = :step.Id
        ];
        System.assertEquals(approvers[1].Id, saved.Approver__c);
        System.assertEquals(250, saved.Approval_Limit__c);
        System.assertEquals(approvers[2].Id, saved.Submits_To_Override__c);
        System.assertEquals(false, saved.Is_Active__c);
    }

    @isTest
    static void testUpdateStepValidation() {
        Test.startTest();
        try {
            ApprovalWorkflowService.updateStep(null, null, null, null, null);
            System.assert(false, 'Should throw for missing step');
        } catch (ApprovalWorkflowService.WorkflowException e) {
            System.assert(e.getMessage().contains('Step'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRemoveStepResequences() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        Approval_Chain__c s1 = ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 100, null);
        Approval_Chain__c s2 = ApprovalWorkflowService.addStep(policy.Id, approvers[1].Id, 200, null);
        Approval_Chain__c s3 = ApprovalWorkflowService.addStep(policy.Id, approvers[2].Id, 300, null);

        Test.startTest();
        ApprovalWorkflowService.removeStep(s2.Id);
        Test.stopTest();

        List<Approval_Chain__c> steps = ApprovalWorkflowService.getSteps(policy.Id);
        System.assertEquals(2, steps.size());
        System.assertEquals(1, steps[0].Order__c);
        System.assertEquals(2, steps[1].Order__c);
        System.assertEquals(approvers[0].Id, steps[0].Approver__c);
        System.assertEquals(approvers[2].Id, steps[1].Approver__c);
    }

    @isTest
    static void testRemoveStepValidation() {
        Test.startTest();
        try {
            ApprovalWorkflowService.removeStep(null);
            System.assert(false, 'Should throw for missing step');
        } catch (ApprovalWorkflowService.WorkflowException e) {
            System.assert(e.getMessage().contains('Step'));
        }
        Test.stopTest();
    }

    @isTest
    static void testReorderSteps() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        Approval_Chain__c s1 = ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 100, null);
        Approval_Chain__c s2 = ApprovalWorkflowService.addStep(policy.Id, approvers[1].Id, 200, null);
        Approval_Chain__c s3 = ApprovalWorkflowService.addStep(policy.Id, approvers[2].Id, 300, null);

        Test.startTest();
        ApprovalWorkflowService.reorderSteps(policy.Id, new List<Id>{s3.Id, s1.Id, s2.Id});
        Test.stopTest();

        List<Approval_Chain__c> steps = ApprovalWorkflowService.getSteps(policy.Id);
        System.assertEquals(approvers[2].Id, steps[0].Approver__c);
        System.assertEquals(approvers[0].Id, steps[1].Approver__c);
        System.assertEquals(approvers[1].Id, steps[2].Approver__c);
    }

    @isTest
    static void testReorderEmptyIsNoop() {
        Expense_Policy__c policy = getPolicy();
        Test.startTest();
        ApprovalWorkflowService.reorderSteps(policy.Id, new List<Id>());
        Test.stopTest();
        System.assertEquals(0, ApprovalWorkflowService.getSteps(policy.Id).size());
    }

    @isTest
    static void testResolveWithinLimit() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 1000, null);
        ApprovalWorkflowService.addStep(policy.Id, approvers[1].Id, null, null);

        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveNextApprover(policy.Id, 50, null);
        Test.stopTest();

        System.assertEquals(true, res.hasApprover);
        System.assertEquals(approvers[0].Id, res.approverId);
        System.assertEquals(false, res.routedByOverride);
    }

    @isTest
    static void testResolveOverLimitOverride() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 100, approvers[2].Id);

        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveNextApprover(policy.Id, 500, null);
        Test.stopTest();

        System.assertEquals(true, res.hasApprover);
        System.assertEquals(approvers[2].Id, res.approverId);
        System.assertEquals(true, res.routedByOverride);
    }

    @isTest
    static void testResolveOverLimitSkipsToHigherApprover() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 100, null);
        ApprovalWorkflowService.addStep(policy.Id, approvers[1].Id, null, null);

        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveNextApprover(policy.Id, 500, null);
        Test.stopTest();

        System.assertEquals(true, res.hasApprover);
        System.assertEquals(approvers[1].Id, res.approverId);
    }

    @isTest
    static void testResolveNextAfterCurrentApprover() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, null, null);
        ApprovalWorkflowService.addStep(policy.Id, approvers[1].Id, null, null);

        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveNextApprover(policy.Id, 50, approvers[0].Id);
        Test.stopTest();

        System.assertEquals(true, res.hasApprover);
        System.assertEquals(approvers[1].Id, res.approverId);
    }

    @isTest
    static void testResolveAfterLastApproverHasNone() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, null, null);

        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveNextApprover(policy.Id, 50, approvers[0].Id);
        Test.stopTest();

        System.assertEquals(false, res.hasApprover);
    }

    @isTest
    static void testResolveInactiveStepSkipped() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        Approval_Chain__c s1 = ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, null, null);
        ApprovalWorkflowService.addStep(policy.Id, approvers[1].Id, null, null);
        ApprovalWorkflowService.updateStep(s1.Id, null, null, null, false);

        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveNextApprover(policy.Id, 50, null);
        Test.stopTest();

        System.assertEquals(approvers[1].Id, res.approverId);
    }

    @isTest
    static void testResolveNoChain() {
        Expense_Policy__c policy = getPolicy();
        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveNextApprover(policy.Id, 50, null);
        Test.stopTest();
        System.assertEquals(false, res.hasApprover);
    }

    @isTest
    static void testResolveNullPolicy() {
        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveNextApprover(null, 50, null);
        Test.stopTest();
        System.assertEquals(false, res.hasApprover);
    }

    @isTest
    static void testResolveForReport() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 1000, null);

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policy.Id,
            Total_Amount__c = 75
        );
        insert report;

        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveNextApproverForReport(report.Id);
        Test.stopTest();

        System.assertEquals(true, res.hasApprover);
        System.assertEquals(approvers[0].Id, res.approverId);
    }

    @isTest
    static void testResolveForReportValidation() {
        Test.startTest();
        try {
            ApprovalWorkflowService.resolveNextApproverForReport(null);
            System.assert(false, 'Should throw for missing report');
        } catch (ApprovalWorkflowService.WorkflowException e) {
            System.assert(e.getMessage().contains('Report'));
        }
        Test.stopTest();
    }

    @isTest
    static void testInvocableWithReport() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 1000, null);

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policy.Id,
            Total_Amount__c = 75
        );
        insert report;

        InvocableResolveApprover.Request req = new InvocableResolveApprover.Request();
        req.reportId = report.Id;

        Test.startTest();
        List<InvocableResolveApprover.Results> results = InvocableResolveApprover.execute(
            new List<InvocableResolveApprover.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals(true, results[0].hasApprover);
        System.assertEquals(approvers[0].Id, results[0].approverId);
    }

    @isTest
    static void testInvocableWithPolicyAndAmount() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, 100, approvers[2].Id);

        InvocableResolveApprover.Request req = new InvocableResolveApprover.Request();
        req.policyId = policy.Id;
        req.amount = 500;

        Test.startTest();
        List<InvocableResolveApprover.Results> results = InvocableResolveApprover.execute(
            new List<InvocableResolveApprover.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals(approvers[2].Id, results[0].approverId);
        System.assertEquals(true, results[0].routedByOverride);
    }

    @isTest
    static void testInvocableError() {
        InvocableResolveApprover.Request req = new InvocableResolveApprover.Request();
        req.reportId = '500000000000000AAA';

        Test.startTest();
        List<InvocableResolveApprover.Results> results = InvocableResolveApprover.execute(
            new List<InvocableResolveApprover.Request>{req}
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assertNotEquals(null, results[0].errorMessage);
    }

    @isTest
    static void testAuraWrappers() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();

        Test.startTest();
        Approval_Chain__c step = ApprovalWorkflowService.addApprovalStep(policy.Id, approvers[0].Id, 100, null);
        ApprovalWorkflowService.addApprovalStep(policy.Id, approvers[1].Id, 200, null);
        ApprovalWorkflowService.updateApprovalStep(step.Id, approvers[0].Id, 150, null, true);
        ApprovalWorkflowService.reorderApprovalSteps(policy.Id, new List<Id>{step.Id});
        List<Approval_Chain__c> steps = ApprovalWorkflowService.getApprovalSteps(policy.Id);
        List<Policy_Member__c> options = ApprovalWorkflowService.getApproverOptions(policy.Id);
        ApprovalWorkflowService.removeApprovalStep(step.Id);
        Test.stopTest();

        System.assertEquals(2, steps.size());
        System.assert(options.size() >= 3);
        System.assertEquals(1, ApprovalWorkflowService.getApprovalSteps(policy.Id).size());
    }

    @isTest
    static void testResolveApproverForReportAura() {
        Expense_Policy__c policy = getPolicy();
        List<User> approvers = getApprovers();
        ApprovalWorkflowService.addStep(policy.Id, approvers[0].Id, null, null);

        Expense_Report__c report = new Expense_Report__c(
            Status__c = 'Open',
            Currency__c = 'USD',
            Policy__c = policy.Id,
            Total_Amount__c = 75
        );
        insert report;

        Test.startTest();
        ApprovalWorkflowService.ApproverResolution res = ApprovalWorkflowService.resolveApproverForReport(report.Id);
        Test.stopTest();

        System.assertEquals(approvers[0].Id, res.approverId);
    }

    @isTest
    static void testGetApproverOptionsValidation() {
        Test.startTest();
        try {
            ApprovalWorkflowService.getApproverOptions(null);
            System.assert(false, 'Should throw for missing policy');
        } catch (ApprovalWorkflowService.WorkflowException e) {
            System.assert(e.getMessage().contains('Policy'));
        }
        Test.stopTest();
    }
}
