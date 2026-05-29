public with sharing class ReceiptService {

    public static Id attachReceipt(Id expenseId, String fileName, Blob fileBody, String contentType) {
        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = fileBody,
            FirstPublishLocationId = expenseId
        );
        insert cv;

        ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        Expense__c expense = new Expense__c(
            Id = expenseId,
            Has_Receipt__c = true,
            Receipt_URL__c = '/sfc/servlet.shepherd/document/download/' + inserted.ContentDocumentId
        );
        update expense;

        return inserted.ContentDocumentId;
    }

    public static void removeReceipt(Id expenseId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :expenseId
        ];

        if (!links.isEmpty()) {
            List<Id> docIds = new List<Id>();
            for (ContentDocumentLink link : links) {
                docIds.add(link.ContentDocumentId);
            }
            delete [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
        }

        Expense__c expense = new Expense__c(
            Id = expenseId,
            Has_Receipt__c = false,
            Receipt_URL__c = null
        );
        update expense;
    }

    public static void replaceReceipt(Id expenseId, String fileName, Blob fileBody, String contentType) {
        removeReceipt(expenseId);
        attachReceipt(expenseId, fileName, fileBody, contentType);
    }

    public static List<ContentVersion> getReceipts(Id expenseId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :expenseId
        ];

        if (links.isEmpty()) return new List<ContentVersion>();

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }

        return [
            SELECT Id, Title, FileExtension, ContentSize, CreatedDate,
                   ContentDocumentId, VersionNumber
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND IsLatest = true
            ORDER BY CreatedDate DESC
        ];
    }

    public static String getReceiptUrl(Id expenseId) {
        Expense__c expense = [SELECT Receipt_URL__c FROM Expense__c WHERE Id = :expenseId LIMIT 1];
        return expense.Receipt_URL__c;
    }
}
