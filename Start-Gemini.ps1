param(
    [string]$GeminiCliPath = "gemini.cmd",
    [switch]$SetApiKey,
    [switch]$ClearApiKey,
    [ValidateSet("gemini-2.5-flash", "gemini-2.5-pro")]
    [string]$Model = "gemini-2.5-flash"
)

# For PowerShell 5.1 compat
Add-Type -AssemblyName System.Security

$ErrorActionPreference = "Stop"

# Define the path for the encrypted API key file
$encryptedKeyFilePath = Join-Path $HOME ".gemini_api_key.enc"

function Protect-GeminiApiKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainText
    )
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
        $protectedBytes = [System.Security.Cryptography.ProtectedData]::Protect($bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        return [System.Convert]::ToBase64String($protectedBytes)
    }
    catch {
        throw "Failed to encrypt API Key: $($_.Exception.Message)"
    }
}

function Unprotect-GeminiApiKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EncryptedText
    )

    $protectedBytes = [System.Convert]::FromBase64String($EncryptedText)
    $bytes = [System.Security.Cryptography.ProtectedData]::Unprotect($protectedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

if ($SetApiKey) {
    $ApiKey = Read-Host -Prompt "Please enter your Gemini API Key" -AsSecureString | ConvertFrom-SecureString -AsPlainText
    $encryptedApiKey = Protect-GeminiApiKey -PlainText $ApiKey
    Set-Content -Path $encryptedKeyFilePath -Value $encryptedApiKey
    Write-Host "Gemini API Key successfully encrypted and stored at '$encryptedKeyFilePath'."
}
elseif ($ClearApiKey) {
    if (Test-Path $encryptedKeyFilePath) {
        Remove-Item -Path $encryptedKeyFilePath -Force
        Write-Host "Gemini API Key successfully removed from '$encryptedKeyFilePath'."
    }
    else {
        Write-Host "No encrypted Gemini API Key found at '$encryptedKeyFilePath'."
    }
}
else {
    if (Test-Path $encryptedKeyFilePath) {
        $encryptedApiKey = Get-Content -Path $encryptedKeyFilePath
        $geminiApiKey = Unprotect-GeminiApiKey -EncryptedText $encryptedApiKey

        $env:GEMINI_API_KEY = $geminiApiKey
        $env:GEMINI_MODEL = $Model

        Write-Host "Gemini API Key loaded from encrypted storage."
        & $GeminiCliPath

        Remove-Item Env:\GEMINI_API_KEY
        Remove-Item Env:\GEMINI_MODEL
    }
    else {
        throw "Encrypted Gemini API Key not found at '$encryptedKeyFilePath'. Please set it using: .\Start-Gemini.ps1 -SetApiKey"
    }
}
