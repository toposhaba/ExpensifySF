trigger ExpenseTrigger on Expense__c (before insert, before update, after insert, after update, after delete) {
    ExpenseTriggerHandler.handleTrigger(Trigger.new, Trigger.old, Trigger.operationType);
}
