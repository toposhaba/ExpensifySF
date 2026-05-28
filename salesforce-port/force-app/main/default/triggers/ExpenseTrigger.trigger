trigger ExpenseTrigger on Expense__c (after insert, after update, after delete) {
    ExpenseTriggerHandler.handleTrigger(Trigger.new, Trigger.old, Trigger.operationType);
}
