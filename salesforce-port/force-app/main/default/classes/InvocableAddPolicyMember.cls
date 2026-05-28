public with sharing class InvocableAddPolicyMember {

    @InvocableMethod(label='Add Policy Member' description='Adds a user to an expense policy with a specified role and validates no duplicate membership exists' category='Expense Management')
    public static List<Results> execute(List<Request> requests) {
        List<Results> responseList = new List<Results>();
        for (Request req : requests) {
            Results res = new Results();
            try {
                Policy_Member__c member = PolicyService.addMember(
                    req.policyId,
                    req.userId,
                    req.role
                );
                res.membershipId = member.Id;
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
        @InvocableVariable(label='Policy Id' required=true)
        public Id policyId;

        @InvocableVariable(label='User Id' required=true)
        public Id userId;

        @InvocableVariable(label='Role' required=false)
        public String role;
    }

    public class Results {
        @InvocableVariable(label='Membership Id')
        public Id membershipId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
