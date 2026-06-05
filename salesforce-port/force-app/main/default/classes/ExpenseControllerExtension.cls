public with sharing class ExpenseControllerExtension {

    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoices(Id policyId) {
        return InvoiceService.getInvoicesByPolicy(policyId);
    }

    @AuraEnabled
    public static Invoice__c createInvoice(Invoice__c invoice) {
        return InvoiceService.createInvoice(invoice);
    }

    @AuraEnabled
    public static Invoice__c sendInvoice(Id invoiceId) {
        return InvoiceService.sendInvoice(invoiceId);
    }

    @AuraEnabled
    public static Invoice__c markInvoicePaid(Id invoiceId) {
        return InvoiceService.markPaid(invoiceId);
    }

    @AuraEnabled
    public static List<List<Expense__c>> findDuplicates() {
        return DuplicateDetectionService.findAllDuplicatesForUser(UserInfo.getUserId());
    }

    @AuraEnabled
    public static Expense__c mergeDuplicates(Id keepId, List<Id> mergeIds) {
        return DuplicateDetectionService.mergeExpenses(keepId, mergeIds);
    }

    @AuraEnabled(cacheable=true)
    public static List<Approval_Chain__c> getApprovalWorkflow(Id policyId) {
        return ApprovalWorkflowService.getWorkflow(policyId);
    }

    @AuraEnabled
    public static Approval_Chain__c addApprover(Id policyId, Id approverId, Integer orderNum, Decimal approvalLimit) {
        return ApprovalWorkflowService.addApprover(policyId, approverId, orderNum, approvalLimit);
    }

    @AuraEnabled
    public static void removeApprover(Id chainId) {
        ApprovalWorkflowService.removeApprover(chainId);
    }

    @AuraEnabled
    public static void reorderApprovers(Id policyId, List<Id> chainIdsInOrder) {
        ApprovalWorkflowService.reorderApprovers(policyId, chainIdsInOrder);
    }

    @AuraEnabled(cacheable=true)
    public static List<Tax_Configuration__c> getTaxRates(Id policyId) {
        return TaxService.getTaxConfigs(policyId);
    }

    @AuraEnabled
    public static Tax_Configuration__c createTaxRate(Tax_Configuration__c config) {
        return TaxService.createTaxConfig(config);
    }

    @AuraEnabled
    public static void updateTaxRate(Tax_Configuration__c config) {
        TaxService.updateTaxConfig(config);
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Rule__c> getExpenseRules(Id policyId) {
        return ExpenseRuleService.getRules(policyId);
    }

    @AuraEnabled
    public static Expense_Rule__c createExpenseRule(Expense_Rule__c rule) {
        return ExpenseRuleService.createRule(rule);
    }

    @AuraEnabled
    public static void applyExpenseRules(List<Id> expenseIds) {
        ExpenseRuleService.applyRules(expenseIds);
    }

    @AuraEnabled(cacheable=true)
    public static List<Distance_Rate__c> getDistanceRates(Id policyId) {
        return PolicyService.getDistanceRates(policyId);
    }

    @AuraEnabled
    public static Expense__c createDistanceExpense(Id policyId, Id reportId, Decimal distance, String unit) {
        return DistanceExpenseService.createDistanceExpense(policyId, reportId, distance, unit);
    }

    @AuraEnabled(cacheable=true)
    public static List<Per_Diem_Rate__c> getPerDiemRates(Id policyId) {
        return PerDiemService.getRates(policyId);
    }

    @AuraEnabled
    public static Per_Diem_Rate__c createPerDiemRate(Per_Diem_Rate__c rate) {
        return PerDiemService.createRate(rate);
    }

    @AuraEnabled
    public static void importPerDiemRates(Id policyId, String csvContent) {
        PerDiemService.importRates(policyId, csvContent);
    }

    @AuraEnabled
    public static Map<String, Object> syncToAccounting(Id reportId, String provider) {
        switch on provider {
            when 'QuickBooks' { return AccountingIntegrationService.syncToQuickBooks(reportId); }
            when 'Xero' { return AccountingIntegrationService.syncToXero(reportId); }
            when 'NetSuite' { return AccountingIntegrationService.syncToNetSuite(reportId); }
            when 'SageIntacct' { return AccountingIntegrationService.syncToSageIntacct(reportId); }
            when else { throw new AuraHandledException('Unknown provider: ' + provider); }
        }
    }

    @AuraEnabled
    public static List<Expense__c> importExpensesCsv(String csvContent, Id policyId, Id reportId) {
        return ImportExportService.importFromCsv(csvContent, policyId, reportId);
    }

    @AuraEnabled
    public static String exportReportCsv(Id reportId) {
        return ImportExportService.exportReportToCsv(reportId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Card__c> getCards(Id policyId) {
        return CardService.getCardsByPolicy(policyId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Card__c> getMyCards() {
        return CardService.getCardsByUser(UserInfo.getUserId());
    }

    @AuraEnabled
    public static Card__c issueCard(Id policyId, Id userId, Decimal spendLimit, String cardName) {
        return CardService.issueCard(policyId, userId, spendLimit, cardName);
    }

    @AuraEnabled
    public static void freezeCard(Id cardId) {
        CardService.freezeCard(cardId);
    }

    @AuraEnabled
    public static void unfreezeCard(Id cardId) {
        CardService.unfreezeCard(cardId);
    }

    @AuraEnabled
    public static void updateCardLimit(Id cardId, Decimal newLimit) {
        CardService.updateSpendLimit(cardId, newLimit);
    }

    @AuraEnabled(cacheable=true)
    public static List<Bank_Account__c> getMyBankAccounts() {
        return BankAccountService.getUserAccounts(UserInfo.getUserId());
    }

    @AuraEnabled
    public static Bank_Account__c addBankAccount(Bank_Account__c account) {
        return BankAccountService.addBankAccount(account);
    }

    @AuraEnabled
    public static void setDefaultBankAccount(Id accountId) {
        BankAccountService.setDefault(accountId, UserInfo.getUserId());
    }

    @AuraEnabled
    public static void deactivateBankAccount(Id accountId) {
        BankAccountService.deactivateAccount(accountId);
    }

    @AuraEnabled
    public static Wallet__c getMyWallet() {
        return BankAccountService.getOrCreateWallet(UserInfo.getUserId());
    }

    @AuraEnabled
    public static void processReimbursement(Id reportId, Id bankAccountId) {
        BankAccountService.processReimbursement(reportId, bankAccountId);
    }

    @AuraEnabled
    public static List<Expense_Comment__c> getComments(Id expenseId) {
        return CommentService.getComments(expenseId);
    }

    @AuraEnabled
    public static Expense_Comment__c addComment(Id expenseId, String body) {
        return CommentService.addComment(expenseId, body);
    }

    @AuraEnabled
    public static List<ContentVersion> getReceipts(Id expenseId) {
        return ReceiptService.getReceipts(expenseId);
    }

    @AuraEnabled
    public static void removeReceipt(Id expenseId) {
        ReceiptService.removeReceipt(expenseId);
    }
}
