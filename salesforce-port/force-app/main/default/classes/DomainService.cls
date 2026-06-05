public with sharing class DomainService {

    public static Domain__c createDomain(Domain__c domain) {
        if (domain.Owner__c == null) {
            domain.Owner__c = UserInfo.getUserId();
        }
        Database.insert(domain, AccessLevel.USER_MODE);

        Domain_Member__c adminMember = new Domain_Member__c(
            Domain__c = domain.Id,
            User__c = domain.Owner__c,
            Role__c = 'Admin'
        );
        Database.insert(adminMember, AccessLevel.USER_MODE);

        return domain;
    }

    @AuraEnabled
    public static Domain__c createDomainByName(String domainName, Id defaultPolicyId) {
        if (String.isBlank(domainName)) {
            throw new DomainException('Domain name is required');
        }
        Domain__c domain = new Domain__c(
            Name = domainName,
            Owner__c = UserInfo.getUserId(),
            Verified__c = false,
            Default_Policy__c = defaultPolicyId
        );
        return createDomain(domain);
    }

    @AuraEnabled(cacheable=true)
    public static Domain__c getDomain(Id domainId) {
        List<Domain__c> domains = [
            SELECT Id, Name, Owner__c, Owner__r.Name, Verified__c,
                   Default_Policy__c, Default_Policy__r.Name, CreatedDate
            FROM Domain__c
            WHERE Id = :domainId
            WITH USER_MODE
            LIMIT 1
        ];
        if (domains.isEmpty()) {
            throw new DomainException('Domain not found');
        }
        return domains[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<Domain__c> getDomainsForUser(Id userId) {
        List<Domain_Member__c> memberships = [
            SELECT Domain__c
            FROM Domain_Member__c
            WHERE User__c = :userId
            WITH USER_MODE
        ];

        Set<Id> domainIds = new Set<Id>();
        for (Domain_Member__c dm : memberships) {
            domainIds.add(dm.Domain__c);
        }

        return [
            SELECT Id, Name, Owner__c, Owner__r.Name, Verified__c,
                   Default_Policy__c, Default_Policy__r.Name
            FROM Domain__c
            WHERE Id IN :domainIds
            WITH USER_MODE
            ORDER BY Name
        ];
    }

    @AuraEnabled
    public static List<Domain__c> getMyDomains() {
        return getDomainsForUser(UserInfo.getUserId());
    }

    @AuraEnabled
    public static Domain__c updateDomain(Domain__c domain) {
        Database.update(domain, AccessLevel.USER_MODE);
        return getDomain(domain.Id);
    }

    @AuraEnabled
    public static void deleteDomain(Id domainId) {
        List<Domain_Member__c> members = [
            SELECT Id
            FROM Domain_Member__c
            WHERE Domain__c = :domainId
            WITH USER_MODE
        ];
        if (!members.isEmpty()) {
            Database.delete(members, AccessLevel.USER_MODE);
        }
        Domain__c domain = new Domain__c(Id = domainId);
        Database.delete(domain, AccessLevel.USER_MODE);
    }

    @AuraEnabled
    public static Domain__c verifyDomain(Id domainId) {
        Domain__c domain = new Domain__c(
            Id = domainId,
            Verified__c = true
        );
        Database.update(domain, AccessLevel.USER_MODE);
        return getDomain(domainId);
    }

    public static Domain_Member__c addMember(Id domainId, Id userId, String role) {
        List<Domain_Member__c> existing = [
            SELECT Id
            FROM Domain_Member__c
            WHERE Domain__c = :domainId AND User__c = :userId
            WITH USER_MODE
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new DomainException('User is already a member of this domain');
        }

        Domain_Member__c member = new Domain_Member__c(
            Domain__c = domainId,
            User__c = userId,
            Role__c = String.isBlank(role) ? 'Member' : role
        );
        Database.insert(member, AccessLevel.USER_MODE);
        return member;
    }

    @AuraEnabled
    public static Domain_Member__c addMemberToDomain(Id domainId, Id userId, String role) {
        return addMember(domainId, userId, role);
    }

    @AuraEnabled
    public static void removeMember(Id domainId, Id userId) {
        List<Domain_Member__c> members = [
            SELECT Id, Role__c
            FROM Domain_Member__c
            WHERE Domain__c = :domainId AND User__c = :userId
            WITH USER_MODE
            LIMIT 1
        ];
        if (members.isEmpty()) {
            throw new DomainException('User is not a member of this domain');
        }
        if (members[0].Role__c == 'Admin') {
            Integer adminCount = [
                SELECT COUNT()
                FROM Domain_Member__c
                WHERE Domain__c = :domainId AND Role__c = 'Admin'
                WITH USER_MODE
            ];
            if (adminCount <= 1) {
                throw new DomainException('Cannot remove the last admin');
            }
        }
        Database.delete(members, AccessLevel.USER_MODE);
    }

    @AuraEnabled
    public static Domain_Member__c updateMemberRole(Id domainId, Id userId, String newRole) {
        List<Domain_Member__c> members = [
            SELECT Id, Role__c
            FROM Domain_Member__c
            WHERE Domain__c = :domainId AND User__c = :userId
            WITH USER_MODE
            LIMIT 1
        ];
        if (members.isEmpty()) {
            throw new DomainException('User is not a member of this domain');
        }
        members[0].Role__c = newRole;
        Database.update(members, AccessLevel.USER_MODE);
        return members[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<Domain_Member__c> getMembers(Id domainId) {
        return [
            SELECT Id, Name, User__c, User__r.Name, User__r.Email, Role__c, CreatedDate
            FROM Domain_Member__c
            WHERE Domain__c = :domainId
            WITH USER_MODE
            ORDER BY Role__c, User__r.Name
        ];
    }

    public static Boolean isAdmin(Id domainId, Id userId) {
        Integer count = [
            SELECT COUNT()
            FROM Domain_Member__c
            WHERE Domain__c = :domainId AND User__c = :userId AND Role__c = 'Admin'
            WITH USER_MODE
        ];
        return count > 0;
    }

    public static Boolean isMember(Id domainId, Id userId) {
        Integer count = [
            SELECT COUNT()
            FROM Domain_Member__c
            WHERE Domain__c = :domainId AND User__c = :userId
            WITH USER_MODE
        ];
        return count > 0;
    }

    public class DomainException extends Exception {}
}
