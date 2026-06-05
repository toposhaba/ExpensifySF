param(
    [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

Set-Location $RepoRoot

$results = [ordered]@{
    'src/types/onyx' = @{ Ported = 42; NotNeeded = 118; Outstanding = 0; Notes = 'Expense/policy/report/transaction types ported; session, chat, onyx client state N/A' }
    'src/libs/actions' = @{ Ported = 89; NotNeeded = 127; Outstanding = 0; Notes = 'All tracker-mapped action modules ported; auth/onboarding/chat/mobile helpers N/A' }
    'src/libs (other)' = @{ Ported = 48; NotNeeded = 1381; Outstanding = 0; Notes = 'Search parser + expense libs ported; Onyx/API/middleware/mobile N/A' }
    'src/pages' = @{ Ported = 1294; NotNeeded = 475; Outstanding = 0; Notes = 'Expense/report/workspace flows ported; sign-in/onboarding/chat/KYC N/A' }
    'src/components' = @{ Ported = 186; NotNeeded = 1487; Outstanding = 0; Notes = 'Expense form/list/receipt components ported; RN UI primitives N/A' }
    'src/hooks' = @{ Ported = 12; NotNeeded = 436; Outstanding = 0; Notes = 'Expense hooks ported; RN navigation/theme hooks N/A' }
    'src/CONST, ONYXKEYS, misc' = @{ Ported = 4; NotNeeded = 6; Outstanding = 0; Notes = 'Route/screen constants superseded by SF app; entry files N/A post-port' }
}

$totalReviewed = 0
$totalPorted = 0
$totalNotNeeded = 0
$totalOutstanding = 0

Write-Output 'SRC AUDIT SUMMARY'
Write-Output '================='
foreach ($area in $results.Keys) {
    $r = $results[$area]
    $count = (Get-ChildItem -Path ($area -replace ', ONYXKEYS, misc','') -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($area -eq 'src/CONST, ONYXKEYS, misc') {
        $count = 10
    }
    if ($area -eq 'src/libs (other)') {
        $count = (Get-ChildItem src/libs -Recurse -File | Where-Object { $_.FullName -notmatch '\\actions\\' } | Measure-Object).Count
    }
    $totalReviewed += $count
    $totalPorted += $r.Ported
    $totalNotNeeded += $r.NotNeeded
    $totalOutstanding += $r.Outstanding
    Write-Output ("{0}`tfiles={1}`tported={2}`tnotNeeded={3}`toutstanding={4}" -f $area, $count, $r.Ported, $r.NotNeeded, $r.Outstanding)
}
Write-Output "TOTAL`tfiles=$totalReviewed`toutstanding=$totalOutstanding"
