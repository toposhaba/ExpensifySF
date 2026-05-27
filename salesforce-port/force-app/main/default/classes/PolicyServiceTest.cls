@isTest
private class PolicyServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Test Policy',
            Currency__c = 'USD',
            Type__c = 'Team',
            Categories_Enabled__c = true,
            Tags_Enabled__c = true
        );
        insert policy;

        Policy_Member__c admin = new Policy_Member__c(
            Policy__c = policy.Id,
            User__c = UserInfo.getUserId(),
            Role__c = 'Admin'
        );
        insert admin;
    }

    @isTest
    static void testCreatePolicy() {
        Test.startTest();
        Expense_Policy__c policy = PolicyService.createPolicy(new Expense_Policy__c(
            Name = 'New Policy',
            Currency__c = 'EUR',
            Type__c = 'Corporate'
        ));
        Test.stopTest();

        System.assertNotEquals(null, policy.Id);

        List<Policy_Member__c> members = [
            SELECT Role__c FROM Policy_Member__c
            WHERE Policy__c = :policy.Id AND User__c = :UserInfo.getUserId()
        ];
        System.assertEquals(1, members.size());
        System.assertEquals('Admin', members[0].Role__c);
    }

    @isTest
    static void testAddMember() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser.expense@test.com',
            Username = 'testuser.expense' + DateTime.now().getTime() + '@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        Test.startTest();
        Policy_Member__c member = PolicyService.addMember(policy.Id, testUser.Id, 'Member');
        Test.stopTest();

        System.assertNotEquals(null, member.Id);
        System.assertEquals('Member', member.Role__c);
    }

    @isTest
    static void testAddMember_Duplicate() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Test.startTest();
        try {
            PolicyService.addMember(policy.Id, UserInfo.getUserId(), 'Member');
            System.assert(false, 'Should throw exception');
        } catch (PolicyService.PolicyException e) {
            System.assert(e.getMessage().contains('already a member'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRemoveMember_LastAdmin() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Test.startTest();
        try {
            PolicyService.removeMember(policy.Id, UserInfo.getUserId());
            System.assert(false, 'Should throw exception');
        } catch (PolicyService.PolicyException e) {
            System.assert(e.getMessage().contains('last admin'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetPoliciesForUser() {
        Test.startTest();
        List<Expense_Policy__c> policies = PolicyService.getPoliciesForUser(UserInfo.getUserId());
        Test.stopTest();

        System.assert(!policies.isEmpty());
    }

    @isTest
    static void testCreateCategory() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Test.startTest();
        Expense_Category__c category = PolicyService.createCategory(new Expense_Category__c(
            Name = 'Meals',
            Policy__c = policy.Id,
            GL_Code__c = '5002',
            Enabled__c = true
        ));
        Test.stopTest();

        System.assertNotEquals(null, category.Id);
    }

    @isTest
    static void testCreateTag() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Test.startTest();
        Expense_Tag__c tag = PolicyService.createTag(new Expense_Tag__c(
            Name = 'Project Alpha',
            Policy__c = policy.Id,
            GL_Code__c = 'PA01',
            Enabled__c = true
        ));
        Test.stopTest();

        System.assertNotEquals(null, tag.Id);
    }

    @isTest
    static void testIsAdmin() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Test.startTest();
        Boolean result = PolicyService.isAdmin(policy.Id, UserInfo.getUserId());
        Test.stopTest();

        System.assert(result);
    }

    @isTest
    static void testIsMember() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Test.startTest();
        Boolean result = PolicyService.isMember(policy.Id, UserInfo.getUserId());
        Test.stopTest();

        System.assert(result);
    }

    @isTest
    static void testGetMemberRole() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Test.startTest();
        String role = PolicyService.getMemberRole(policy.Id, UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals('Admin', role);
    }

    @isTest
    static void testUpdateMemberRole() {
        Expense_Policy__c policy = [SELECT Id FROM Expense_Policy__c LIMIT 1];

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Role',
            LastName = 'Test',
            Email = 'roletest.expense@test.com',
            Username = 'roletest.expense' + DateTime.now().getTime() + '@test.com',
            Alias = 'rtest',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        Policy_Member__c member = new Policy_Member__c(
            Policy__c = policy.Id,
            User__c = testUser.Id,
            Role__c = 'Member'
        );
        insert member;

        Test.startTest();
        PolicyService.updateMemberRole(policy.Id, testUser.Id, 'Approver');
        Test.stopTest();

        Policy_Member__c updated = [SELECT Role__c FROM Policy_Member__c WHERE Id = :member.Id];
        System.assertEquals('Approver', updated.Role__c);
    }
}
