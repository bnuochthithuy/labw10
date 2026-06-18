# PowerShell script to generate cosign keypair with pre-filled password
# Usage: .\generate-cosign-key.ps1

param(
    [string]$Password = "Lab2.2Pass123!"  # Change this to your secure password
)

Write-Host "🔑 Generating Cosign Keypair..."
Write-Host "📝 Password: $Password"
Write-Host ""

# Change to labw10 directory
Set-Location d:\gitOps\labw10

# Use echo to pipe password twice (both for entry and confirmation)
# This works because echo outputs the same string multiple times
$output = @"
$Password
$Password
"@ | C:/Users/User/tools/cosign.exe generate-key-pair 2>&1

Write-Host $output

# Check if successful
if (Test-Path "cosign.key" -PathType Leaf) {
    Write-Host ""
    Write-Host "✅ SUCCESS! Generated:"
    Write-Host "  - cosign.key (PRIVATE - keep safe!)"
    Write-Host "  - cosign.pub (PUBLIC)"
    Write-Host ""
    Write-Host "📋 Next steps:"
    Write-Host "  1. Save this password: $Password"
    Write-Host "  2. Add to GitHub Secrets:"
    Write-Host "     - COSIGN_PRIVATE_KEY: (contents of cosign.key)"
    Write-Host "     - COSIGN_PASSWORD: $Password"
    Write-Host "  3. Copy public key: cp cosign.pub temp/signing/cosign.pub"
    Write-Host "  4. Commit: git add .gitignore temp/signing/cosign.pub && git commit -m 'chore: setup cosign'"
    Write-Host ""
    Write-Host "💾 Save this password somewhere safe!"
} else {
    Write-Host ""
    Write-Host "❌ FAILED! Check error messages above"
    Write-Host "Try running manually:"
    Write-Host "  C:/Users/User/tools/cosign.exe generate-key-pair"
}
