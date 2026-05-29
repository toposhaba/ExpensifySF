public with sharing class ApprovalWorkflowService {

    public static Approval_Chain__c addApprover(Id policyId, Id approverId, Integer orderNum, Decimal approvalLimit) {
        Approval_Chain__c chain = new Approval_Chain__c(
            Policy__c = policyId,
            Approver__c = approverId,
            Order__c = orderNum,
            Approval_Limit__c = approvalLimit
        );
        insert chain;
        return chain;
    }

    public static void removeApprover(Id chainId) {
        Approval_Chain__c toDelete = [SELECT Id, Policy__c, Order__c FROM Approval_Chain__c WHERE Id = :chainId LIMIT 1];
        Id policyId = toDelete.Policy__c;
        Decimal deletedOrder = toDelete.Order__c;
        delete toDelete;

        List<Approval_Chain__c> toReorder = [
            SELECT Id, Order__c FROM Approval_Chain__c
            WHERE Policy__c = :policyId AND Order__c > :deletedOrder ORDER BY Order__c
        ];
        for (Approval_Chain__c ac : toReorder) {
            ac.Order__c = ac.Order__c - 1;
        }
        if (!toReorder.isEmpty()) update toReorder;
    }

    public static void reorderApprovers(Id policyId, List<Id> chainIdsInOrder) {
        List<Approval_Chain__c> chains = new List<Approval_Chain__c>();
        for (Integer i = 0; i < chainIdsInOrder.size(); i++) {
            chains.add(new Approval_Chain__c(Id = chainIdsInOrder[i], Order__c = i + 1));
        }
        update chains;
    }

    public static List<Approval_Chain__c> getWorkflow(Id policyId) {
        return [
            SELECT Id, Approver__c, Approver__r.Name, Approver__r.Email,
                   Order__c, Approval_Limit__c
            FROM Approval_Chain__c WHERE Policy__c = :policyId ORDER BY Order__c ASC
        ];
    }

    public static void updateApproverLimit(Id chainId, Decimal newLimit) {
        update new Approval_Chain__c(Id = chainId, Approval_Limit__c = newLimit);
    }

    public static Id getNextApprover(Id policyId, Decimal reportAmount, Id currentApproverId) {
        List<Approval_Chain__c> chain = [
            SELECT Approver__c, Approval_Limit__c, Order__c FROM Approval_Chain__c
            WHERE Policy__c = :policyId ORDER BY Order__c ASC
        ];

        Boolean foundCurrent = (currentApproverId == null);
        for (Approval_Chain__c ac : chain) {
            if (!foundCurrent) {
                if (ac.Approver__c == currentApproverId) foundCurrent = true;
                continue;
            }
            if (ac.Approval_Limit__c == null || reportAmount <= ac.Approval_Limit__c) {
                return ac.Approver__c;
            }
        }
        return chain.isEmpty() ? null : chain[chain.size() - 1].Approver__c;
    }

    public static void setMemberApprover(Id policyId, Id userId, Id approverId) {
        List<Policy_Member__c> members = [
            SELECT Id FROM Policy_Member__c WHERE Policy__c = :policyId AND User__c = :userId LIMIT 1
        ];
        if (!members.isEmpty()) {
            members[0].Submits_To__c = approverId;
            update members;
        }
    }
}
