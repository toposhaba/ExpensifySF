public with sharing class InvocableAddDomainMember {

    @InvocableMethod(label='Add Domain Member' description='Adds a user to a domain with a role' category='Domain Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Domain_Member__c member = DomainService.addMember(
                    req.domainId,
                    req.userId,
                    req.role != null ? req.role : 'Member'
                );
                res.memberId = member.Id;
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
        @InvocableVariable(label='Domain Id' required=true)
        public Id domainId;

        @InvocableVariable(label='User Id' required=true)
        public Id userId;

        @InvocableVariable(label='Role' required=false)
        public String role;
    }

    public class Results {
        @InvocableVariable(label='Member Id')
        public Id memberId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
