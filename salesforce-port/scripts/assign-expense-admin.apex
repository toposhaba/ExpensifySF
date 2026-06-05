PermissionSet ps = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'Expense_Admin'
    LIMIT 1
];
Id userId = UserInfo.getUserId();
List<PermissionSetAssignment> existing = [
    SELECT Id
    FROM PermissionSetAssignment
    WHERE AssigneeId = :userId AND PermissionSetId = :ps.Id
    LIMIT 1
];
if (existing.isEmpty()) {
    insert new PermissionSetAssignment(
        AssigneeId = userId,
        PermissionSetId = ps.Id
    );
}
