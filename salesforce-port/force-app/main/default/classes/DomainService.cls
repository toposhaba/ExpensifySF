public with sharing class DomainService {

    public static Domain__c createDomain(String domainName) {
        Domain__c domain = new Domain__c(
            Name = domainName,
            Status__c = 'Pending_Verification',
            Created_Date__c = Date.today()
        );
        insert domain;
        return domain;
    }

    public static void verifyDomain(Id domainId) {
        update new Domain__c(Id = domainId, Status__c = 'Verified', Verified_Date__c = Date.today());
    }

    public static Domain_Member__c addMember(Id domainId, Id userId, String role) {
        Domain_Member__c member = new Domain_Member__c(
            Domain__c = domainId,
            User__c = userId,
            Role__c = role != null ? role : 'Member',
            Two_Factor_Required__c = false
        );
        insert member;
        return member;
    }

    public static void removeMember(Id domainId, Id userId) {
        List<Domain_Member__c> members = [
            SELECT Id FROM Domain_Member__c WHERE Domain__c = :domainId AND User__c = :userId
        ];
        if (!members.isEmpty()) delete members;
    }

    public static List<Domain_Member__c> getMembers(Id domainId) {
        return [
            SELECT Id, User__c, User__r.Name, User__r.Email, Role__c,
                   Two_Factor_Required__c, CreatedDate
            FROM Domain_Member__c WHERE Domain__c = :domainId ORDER BY User__r.Name
        ];
    }

    public static void updateSamlConfig(Id domainId, String issuer, String loginUrl, String certificate) {
        update new Domain__c(
            Id = domainId,
            SAML_Issuer__c = issuer,
            SAML_Login_URL__c = loginUrl,
            SAML_Certificate__c = certificate,
            SAML_Enabled__c = true
        );
    }

    public static void disableSaml(Id domainId) {
        update new Domain__c(Id = domainId, SAML_Enabled__c = false);
    }

    public static void enforceTwoFactor(Id domainId, Boolean enforce) {
        List<Domain_Member__c> members = [
            SELECT Id FROM Domain_Member__c WHERE Domain__c = :domainId
        ];
        for (Domain_Member__c m : members) {
            m.Two_Factor_Required__c = enforce;
        }
        if (!members.isEmpty()) update members;
    }

    public static List<Domain__c> getDomainsForUser(Id userId) {
        List<Domain_Member__c> memberships = [SELECT Domain__c FROM Domain_Member__c WHERE User__c = :userId];
        Set<Id> domainIds = new Set<Id>();
        for (Domain_Member__c m : memberships) domainIds.add(m.Domain__c);

        return [
            SELECT Id, Name, Status__c, SAML_Enabled__c, Verified_Date__c
            FROM Domain__c WHERE Id IN :domainIds ORDER BY Name
        ];
    }
}
