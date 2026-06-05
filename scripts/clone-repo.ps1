param(
    [string]$Directory = "ExpensifySF",
    [string]$Repo = "https://github.com/toposhaba/ExpensifySF.git"
)

$ErrorActionPreference = "Stop"

if (Test-Path $Directory) {
    throw "Directory '$Directory' already exists."
}

git -c core.longpaths=true clone $Repo $Directory

Write-Host "Cloned to $Directory"
