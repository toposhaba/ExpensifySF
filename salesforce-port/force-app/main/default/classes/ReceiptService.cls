public with sharing class ReceiptService {

    public static final String SCAN_STATUS_PENDING = 'Pending';
    public static final String SCAN_STATUS_PROCESSING = 'Processing';
    public static final String SCAN_STATUS_COMPLETED = 'Completed';
    public static final String SCAN_STATUS_FAILED = 'Failed';

    private static final Set<String> VALID_SCAN_STATUSES = new Set<String>{
        SCAN_STATUS_PENDING, SCAN_STATUS_PROCESSING, SCAN_STATUS_COMPLETED, SCAN_STATUS_FAILED
    };

    @AuraEnabled
    public static Expense_Receipt__c attachReceipt(Id expenseId, Id contentDocumentId) {
        if (expenseId == null) {
            throw new ReceiptException('Expense Id is required');
        }
        if (contentDocumentId == null) {
            throw new ReceiptException('Content Document Id is required');
        }

        requireExpenseAccess(expenseId);
        ContentVersion version = getLatestVersion(contentDocumentId);
        ensureLink(expenseId, contentDocumentId);

        Expense_Receipt__c receipt = new Expense_Receipt__c(
            Expense__c = expenseId,
            Content_Document_Id__c = contentDocumentId,
            Content_Version_Id__c = version != null ? version.Id : null,
            File_Name__c = version != null ? version.Title : null,
            File_URL__c = buildDownloadUrl(contentDocumentId),
            Scan_Status__c = SCAN_STATUS_PENDING
        );

        insertReceipt(receipt);
        markExpenseHasReceipt(expenseId, true);
        return receipt;
    }

    @AuraEnabled
    public static Expense_Receipt__c replaceReceipt(Id receiptId, Id contentDocumentId) {
        if (receiptId == null) {
            throw new ReceiptException('Receipt Id is required');
        }
        if (contentDocumentId == null) {
            throw new ReceiptException('Content Document Id is required');
        }

        Expense_Receipt__c existing = getReceipt(receiptId);
        Id oldContentDocumentId = existing.Content_Document_Id__c;
        ContentVersion version = getLatestVersion(contentDocumentId);
        ensureLink(existing.Expense__c, contentDocumentId);

        Expense_Receipt__c updated = new Expense_Receipt__c(
            Id = receiptId,
            Content_Document_Id__c = contentDocumentId,
            Content_Version_Id__c = version != null ? version.Id : null,
            File_Name__c = version != null ? version.Title : null,
            File_URL__c = buildDownloadUrl(contentDocumentId),
            Scan_Status__c = SCAN_STATUS_PENDING
        );

        updateReceipt(updated);
        markExpenseHasReceipt(existing.Expense__c, true);
        removeOrphanLink(existing.Expense__c, oldContentDocumentId, contentDocumentId);
        return updated;
    }

    @AuraEnabled
    public static void detachReceipt(Id receiptId) {
        if (receiptId == null) {
            throw new ReceiptException('Receipt Id is required');
        }
        Expense_Receipt__c existing = getReceipt(receiptId);
        Id expenseId = existing.Expense__c;

        if (!Schema.sObjectType.Expense_Receipt__c.isDeletable()) {
            throw new ReceiptException('Insufficient access to delete receipts');
        }
        delete existing;

        markExpenseHasReceipt(expenseId, hasRemainingReceipts(expenseId));
    }

    @AuraEnabled
    public static Expense_Receipt__c updateScanStatus(Id receiptId, String status) {
        if (receiptId == null) {
            throw new ReceiptException('Receipt Id is required');
        }
        if (!VALID_SCAN_STATUSES.contains(status)) {
            throw new ReceiptException('Invalid scan status: ' + status);
        }
        Expense_Receipt__c updated = new Expense_Receipt__c(
            Id = receiptId,
            Scan_Status__c = status
        );
        updateReceipt(updated);
        return updated;
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Receipt__c> getReceiptsForExpense(Id expenseId) {
        if (expenseId == null) {
            return new List<Expense_Receipt__c>();
        }
        return [
            SELECT Id, Name, Expense__c, File_URL__c, Thumbnail_URL__c,
                   Content_Document_Id__c, Content_Version_Id__c, File_Name__c,
                   Scan_Status__c, CreatedDate
            FROM Expense_Receipt__c
            WHERE Expense__c = :expenseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
    }

    private static Expense_Receipt__c getReceipt(Id receiptId) {
        List<Expense_Receipt__c> receipts = [
            SELECT Id, Expense__c, Content_Document_Id__c, Content_Version_Id__c, File_URL__c
            FROM Expense_Receipt__c
            WHERE Id = :receiptId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (receipts.isEmpty()) {
            throw new ReceiptException('Receipt not found');
        }
        return receipts[0];
    }

    private static ContentVersion getLatestVersion(Id contentDocumentId) {
        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return versions.isEmpty() ? null : versions[0];
    }

    private static void ensureLink(Id expenseId, Id contentDocumentId) {
        if (expenseId == null || contentDocumentId == null) {
            return;
        }
        List<ContentDocumentLink> existing = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :expenseId AND ContentDocumentId = :contentDocumentId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.ContentDocumentLink.isCreateable()) {
            throw new ReceiptException('Insufficient access to link files');
        }
        ContentDocumentLink link = new ContentDocumentLink(
            LinkedEntityId = expenseId,
            ContentDocumentId = contentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;
    }

    private static void removeOrphanLink(Id expenseId, Id oldContentDocumentId, Id newContentDocumentId) {
        if (oldContentDocumentId == null || oldContentDocumentId == newContentDocumentId) {
            return;
        }
        Integer stillReferenced = [
            SELECT COUNT()
            FROM Expense_Receipt__c
            WHERE Expense__c = :expenseId AND Content_Document_Id__c = :oldContentDocumentId
        ];
        if (stillReferenced > 0) {
            return;
        }
        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :expenseId AND ContentDocumentId = :oldContentDocumentId
            WITH SECURITY_ENFORCED
        ];
        if (!links.isEmpty() && Schema.sObjectType.ContentDocumentLink.isDeletable()) {
            delete links;
        }
    }

    private static Boolean hasRemainingReceipts(Id expenseId) {
        Integer remaining = [SELECT COUNT() FROM Expense_Receipt__c WHERE Expense__c = :expenseId];
        return remaining > 0;
    }

    private static void markExpenseHasReceipt(Id expenseId, Boolean hasReceipt) {
        if (expenseId == null) {
            return;
        }
        if (!Schema.sObjectType.Expense__c.fields.Has_Receipt__c.isUpdateable()) {
            throw new ReceiptException('Insufficient access to update Has Receipt');
        }
        update new Expense__c(Id = expenseId, Has_Receipt__c = hasReceipt);
    }

    private static void insertReceipt(Expense_Receipt__c receipt) {
        if (!Schema.sObjectType.Expense_Receipt__c.isCreateable()) {
            throw new ReceiptException('Insufficient access to create receipts');
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<Expense_Receipt__c>{receipt});
        if (!decision.getRemovedFields().isEmpty() && decision.getRemovedFields().containsKey('Expense_Receipt__c')) {
            throw new ReceiptException('Insufficient field access to create receipts');
        }
        insert receipt;
    }

    private static void updateReceipt(Expense_Receipt__c receipt) {
        if (!Schema.sObjectType.Expense_Receipt__c.isUpdateable()) {
            throw new ReceiptException('Insufficient access to update receipts');
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Expense_Receipt__c>{receipt});
        if (!decision.getRemovedFields().isEmpty() && decision.getRemovedFields().containsKey('Expense_Receipt__c')) {
            throw new ReceiptException('Insufficient field access to update receipts');
        }
        update receipt;
    }

    private static void requireExpenseAccess(Id expenseId) {
        List<Expense__c> expenses = [
            SELECT Id FROM Expense__c WHERE Id = :expenseId WITH SECURITY_ENFORCED LIMIT 1
        ];
        if (expenses.isEmpty()) {
            throw new ReceiptException('Expense not found');
        }
    }

    private static String buildDownloadUrl(Id contentDocumentId) {
        return '/sfc/servlet.shepherd/document/download/' + contentDocumentId;
    }

    public class ReceiptException extends Exception {}
}
