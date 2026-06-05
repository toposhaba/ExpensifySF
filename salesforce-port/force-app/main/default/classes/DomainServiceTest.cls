@isTest
private class DomainServiceTest {

    @TestSetup
    static void setupTestData() {
        Expense_Policy__c policy = new Expense_Policy__c(
            Name = 'Domain Default Policy',
            Currency__c = 'USD',
            Type__c = 'Corporate'
        );
        insert policy;

        Domain__c domain = new Domain__c(
            Name = 'example.com',
            Owner__c = UserInfo.getUserId(),
            Verified__c = false,
            Default_Policy__c = policy.Id
        );
        insert domain;

        Domain_Member__c admin = new Domain_Member__c(
            Domain__c = domain.Id,
            User__c = UserInfo.getUserId(),
            Role__c = 'Admin'
        );
        insert admin;
    }

    private static User createUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Domain',
            LastName = alias,
            Email = alias + '.domain@test.com',
            Username = alias + '.domain' + DateTime.now().getTime() + '@test.com',
            Alias = alias.left(8),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    @isTest
    static void testCreateDomain() {
        Test.startTest();
        Domain__c domain = DomainService.createDomainByName('newdomain.com', null);
        Test.stopTest();

        System.assertNotEquals(null, domain.Id);

        List<Domain_Member__c> members = [
            SELECT Role__c FROM Domain_Member__c
            WHERE Domain__c = :domain.Id AND User__c = :UserInfo.getUserId()
        ];
        System.assertEquals(1, members.size());
        System.assertEquals('Admin', members[0].Role__c);
    }

    @isTest
    static void testCreateDomainBlankName() {
        Test.startTest();
        try {
            DomainService.createDomainByName('', null);
            System.assert(false, 'Should throw exception');
        } catch (DomainService.DomainException e) {
            System.assert(e.getMessage().contains('required'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetDomain() {
        Domain__c existing = [SELECT Id FROM Domain__c LIMIT 1];

        Test.startTest();
        Domain__c domain = DomainService.getDomain(existing.Id);
        Test.stopTest();

        System.assertEquals('example.com', domain.Name);
    }

    @isTest
    static void testGetDomainsForUser() {
        Test.startTest();
        List<Domain__c> domains = DomainService.getMyDomains();
        Test.stopTest();

        System.assert(!domains.isEmpty());
    }

    @isTest
    static void testUpdateDomain() {
        Domain__c existing = [SELECT Id FROM Domain__c LIMIT 1];
        existing.Name = 'updated.com';

        Test.startTest();
        Domain__c updated = DomainService.updateDomain(existing);
        Test.stopTest();

        System.assertEquals('updated.com', updated.Name);
    }

    @isTest
    static void testVerifyDomain() {
        Domain__c existing = [SELECT Id FROM Domain__c LIMIT 1];

        Test.startTest();
        Domain__c verified = DomainService.verifyDomain(existing.Id);
        Test.stopTest();

        System.assertEquals(true, verified.Verified__c);
    }

    @isTest
    static void testAddMember() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];
        User u = createUser('addmem');

        Test.startTest();
        Domain_Member__c member = DomainService.addMember(domain.Id, u.Id, 'Member');
        Test.stopTest();

        System.assertNotEquals(null, member.Id);
        System.assertEquals('Member', member.Role__c);
    }

    @isTest
    static void testAddMemberDuplicate() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];

        Test.startTest();
        try {
            DomainService.addMemberToDomain(domain.Id, UserInfo.getUserId(), 'Member');
            System.assert(false, 'Should throw exception');
        } catch (DomainService.DomainException e) {
            System.assert(e.getMessage().contains('already a member'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRemoveMember() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];
        User u = createUser('rmmem');
        Domain_Member__c member = new Domain_Member__c(
            Domain__c = domain.Id,
            User__c = u.Id,
            Role__c = 'Member'
        );
        insert member;

        Test.startTest();
        DomainService.removeMember(domain.Id, u.Id);
        Test.stopTest();

        List<Domain_Member__c> remaining = [
            SELECT Id FROM Domain_Member__c
            WHERE Domain__c = :domain.Id AND User__c = :u.Id
        ];
        System.assert(remaining.isEmpty());
    }

    @isTest
    static void testRemoveLastAdmin() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];

        Test.startTest();
        try {
            DomainService.removeMember(domain.Id, UserInfo.getUserId());
            System.assert(false, 'Should throw exception');
        } catch (DomainService.DomainException e) {
            System.assert(e.getMessage().contains('last admin'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRemoveMemberNotMember() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];
        User u = createUser('notmem');

        Test.startTest();
        try {
            DomainService.removeMember(domain.Id, u.Id);
            System.assert(false, 'Should throw exception');
        } catch (DomainService.DomainException e) {
            System.assert(e.getMessage().contains('not a member'));
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateMemberRole() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];
        User u = createUser('rolemem');
        Domain_Member__c member = new Domain_Member__c(
            Domain__c = domain.Id,
            User__c = u.Id,
            Role__c = 'Member'
        );
        insert member;

        Test.startTest();
        Domain_Member__c updated = DomainService.updateMemberRole(domain.Id, u.Id, 'Admin');
        Test.stopTest();

        System.assertEquals('Admin', updated.Role__c);
    }

    @isTest
    static void testGetMembers() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];

        Test.startTest();
        List<Domain_Member__c> members = DomainService.getMembers(domain.Id);
        Test.stopTest();

        System.assert(!members.isEmpty());
    }

    @isTest
    static void testIsAdminAndIsMember() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];

        Test.startTest();
        Boolean admin = DomainService.isAdmin(domain.Id, UserInfo.getUserId());
        Boolean member = DomainService.isMember(domain.Id, UserInfo.getUserId());
        Test.stopTest();

        System.assert(admin);
        System.assert(member);
    }

    @isTest
    static void testDeleteDomain() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];

        Test.startTest();
        DomainService.deleteDomain(domain.Id);
        Test.stopTest();

        List<Domain__c> remaining = [SELECT Id FROM Domain__c WHERE Id = :domain.Id];
        System.assert(remaining.isEmpty());
    }

    @isTest
    static void testInvocableAddDomainMember() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];
        User u = createUser('invmem');

        InvocableAddDomainMember.Request req = new InvocableAddDomainMember.Request();
        req.domainId = domain.Id;
        req.userId = u.Id;
        req.role = 'Member';

        Test.startTest();
        List<InvocableAddDomainMember.Results> results =
            InvocableAddDomainMember.execute(new List<InvocableAddDomainMember.Request>{req});
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assertNotEquals(null, results[0].memberId);
    }

    @isTest
    static void testInvocableAddDomainMemberFailure() {
        Domain__c domain = [SELECT Id FROM Domain__c LIMIT 1];

        InvocableAddDomainMember.Request req = new InvocableAddDomainMember.Request();
        req.domainId = domain.Id;
        req.userId = UserInfo.getUserId();
        req.role = 'Member';

        Test.startTest();
        List<InvocableAddDomainMember.Results> results =
            InvocableAddDomainMember.execute(new List<InvocableAddDomainMember.Request>{req});
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assertNotEquals(null, results[0].errorMessage);
    }
}
