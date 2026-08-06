# เปิด URL OAuth ใน Google Chrome (สำหรับ Higgsfield / MCP auth)
# ใช้เมื่อ Cursor เปิด Firefox แทน Chrome
# ตัวอย่าง: .\open-oauth-in-chrome.ps1 "https://mcp.higgsfield.ai/oauth2/authorize?..."

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Url
)

$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) {
    $chrome = "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
}
if (-not (Test-Path $chrome)) {
    Write-Error "ไม่พบ Google Chrome"
    exit 1
}

Start-Process -FilePath $chrome -ArgumentList @($Url)
Write-Host "Opened in Chrome: $Url"
