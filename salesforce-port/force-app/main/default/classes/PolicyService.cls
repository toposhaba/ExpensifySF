public with sharing class PolicyService {

    public static Expense_Policy__c createPolicy(Expense_Policy__c policy) {
        insert policy;

        Policy_Member__c adminMember = new Policy_Member__c(
            Policy__c = policy.Id,
            User__c = UserInfo.getUserId(),
            Role__c = 'Admin'
        );
        insert adminMember;

        return policy;
    }

    public static Expense_Policy__c getPolicy(Id policyId) {
        return [
            SELECT Id, Name, Currency__c, Type__c, Approval_Mode__c,
                   Max_Expense_Amount__c, Max_Expense_Age_Days__c,
                   Receipt_Required_Amount__c, Auto_Approve_Limit__c,
                   Categories_Enabled__c, Tags_Enabled__c, Description__c,
                   OwnerId, Owner.Name, CreatedDate
            FROM Expense_Policy__c
            WHERE Id = :policyId
            LIMIT 1
        ];
    }

    public static List<Expense_Policy__c> getPoliciesForUser(Id userId) {
        List<Policy_Member__c> memberships = [
            SELECT Policy__c
            FROM Policy_Member__c
            WHERE User__c = :userId
        ];

        Set<Id> policyIds = new Set<Id>();
        for (Policy_Member__c pm : memberships) {
            policyIds.add(pm.Policy__c);
        }

        return [
            SELECT Id, Name, Currency__c, Type__c, OwnerId, Owner.Name
            FROM Expense_Policy__c
            WHERE Id IN :policyIds
            ORDER BY Name
        ];
    }

    public static Policy_Member__c addMember(Id policyId, Id userId, String role) {
        List<Policy_Member__c> existing = [
            SELECT Id FROM Policy_Member__c
            WHERE Policy__c = :policyId AND User__c = :userId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new PolicyException('User is already a member of this policy');
        }

        Policy_Member__c member = new Policy_Member__c(
            Policy__c = policyId,
            User__c = userId,
            Role__c = role != null ? role : 'Member'
        );
        insert member;
        return member;
    }

    public static void removeMember(Id policyId, Id userId) {
        List<Policy_Member__c> members = [
            SELECT Id, Role__c
            FROM Policy_Member__c
            WHERE Policy__c = :policyId AND User__c = :userId
            LIMIT 1
        ];
        if (members.isEmpty()) {
            throw new PolicyException('User is not a member of this policy');
        }
        if (members[0].Role__c == 'Admin') {
            Integer adminCount = [
                SELECT COUNT()
                FROM Policy_Member__c
                WHERE Policy__c = :policyId AND Role__c = 'Admin'
            ];
            if (adminCount <= 1) {
                throw new PolicyException('Cannot remove the last admin');
            }
        }
        delete members;
    }

    public static void updateMemberRole(Id policyId, Id userId, String newRole) {
        List<Policy_Member__c> members = [
            SELECT Id, Role__c
            FROM Policy_Member__c
            WHERE Policy__c = :policyId AND User__c = :userId
            LIMIT 1
        ];
        if (members.isEmpty()) {
            throw new PolicyException('User is not a member of this policy');
        }
        members[0].Role__c = newRole;
        update members;
    }

    public static List<Policy_Member__c> getMembers(Id policyId) {
        return [
            SELECT Id, User__c, User__r.Name, User__r.Email, Role__c, Submits_To__c,
                   Submits_To__r.Name, CreatedDate
            FROM Policy_Member__c
            WHERE Policy__c = :policyId
            ORDER BY Role__c, User__r.Name
        ];
    }

    public static Expense_Category__c createCategory(Expense_Category__c category) {
        insert category;
        return category;
    }

    public static List<Expense_Category__c> getCategories(Id policyId) {
        return [
            SELECT Id, Name, GL_Code__c, Enabled__c, Max_Amount__c, Receipt_Required__c
            FROM Expense_Category__c
            WHERE Policy__c = :policyId
            ORDER BY Name
        ];
    }

    public static Expense_Tag__c createTag(Expense_Tag__c tag) {
        insert tag;
        return tag;
    }

    public static List<Expense_Tag__c> getTags(Id policyId) {
        return [
            SELECT Id, Name, GL_Code__c, Enabled__c
            FROM Expense_Tag__c
            WHERE Policy__c = :policyId
            ORDER BY Name
        ];
    }

    public static Distance_Rate__c createDistanceRate(Distance_Rate__c rate) {
        insert rate;
        return rate;
    }

    public static List<Distance_Rate__c> getDistanceRates(Id policyId) {
        return [
            SELECT Id, Name, Rate_Per_Unit__c, Unit__c, Currency__c
            FROM Distance_Rate__c
            WHERE Policy__c = :policyId
        ];
    }

    public static Boolean isAdmin(Id policyId, Id userId) {
        Integer count = [
            SELECT COUNT()
            FROM Policy_Member__c
            WHERE Policy__c = :policyId AND User__c = :userId AND Role__c = 'Admin'
        ];
        return count > 0;
    }

    public static Boolean isMember(Id policyId, Id userId) {
        Integer count = [
            SELECT COUNT()
            FROM Policy_Member__c
            WHERE Policy__c = :policyId AND User__c = :userId
        ];
        return count > 0;
    }

    public static String getMemberRole(Id policyId, Id userId) {
        List<Policy_Member__c> members = [
            SELECT Role__c
            FROM Policy_Member__c
            WHERE Policy__c = :policyId AND User__c = :userId
            LIMIT 1
        ];
        return members.isEmpty() ? null : members[0].Role__c;
    }

    public class PolicyException extends Exception {}
}
