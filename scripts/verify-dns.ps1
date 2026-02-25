<#
.SYNOPSIS
  Verify DNS records for mail.lurus.cn
.DESCRIPTION
  Checks MX, SPF, DKIM, DMARC, PTR, and A records
  required for proper email deliverability.
.EXAMPLE
  .\scripts\verify-dns.ps1
  .\scripts\verify-dns.ps1 -Domain "lurus.cn"
#>

param(
    [string]$Domain = "lurus.cn",
    [string]$MailHost = "mail.lurus.cn",
    [string]$PublicIP = "43.226.46.164"
)

$passed = 0
$failed = 0
$warnings = 0

function Test-DnsRecord {
    param(
        [string]$Label,
        [string]$Type,
        [string]$Name,
        [string]$ExpectedContains = "",
        [switch]$Required
    )

    Write-Host "  Checking $Label ($Type $Name)..." -ForegroundColor Gray -NoNewline

    try {
        $result = Resolve-DnsName -Name $Name -Type $Type -ErrorAction Stop 2>$null
        $values = ($result | ForEach-Object {
            if ($_.QueryType -eq "TXT") { $_.Strings -join "" }
            elseif ($_.QueryType -eq "MX") { "$($_.Preference) $($_.NameExchange)" }
            elseif ($_.QueryType -eq "A") { $_.IPAddress }
            elseif ($_.QueryType -eq "CNAME") { $_.NameHost }
            else { $_.ToString() }
        }) -join "; "

        if ($ExpectedContains -and $values -notlike "*$ExpectedContains*") {
            Write-Host " WARN" -ForegroundColor Yellow
            Write-Host "    Found: $values" -ForegroundColor Yellow
            Write-Host "    Expected to contain: $ExpectedContains" -ForegroundColor Yellow
            $script:warnings++
            return
        }

        Write-Host " OK" -ForegroundColor Green
        Write-Host "    Value: $values" -ForegroundColor DarkGray
        $script:passed++
    }
    catch {
        if ($Required) {
            Write-Host " FAIL" -ForegroundColor Red
            Write-Host "    Record not found!" -ForegroundColor Red
            $script:failed++
        } else {
            Write-Host " MISSING" -ForegroundColor Yellow
            Write-Host "    Record not configured yet" -ForegroundColor Yellow
            $script:warnings++
        }
    }
}

Write-Host "=== DNS Verification for $Domain ===" -ForegroundColor Cyan
Write-Host ""

# A record
Write-Host "[A Records]" -ForegroundColor White
Test-DnsRecord -Label "Mail server A record" -Type A -Name $MailHost -ExpectedContains $PublicIP -Required

Write-Host ""

# MX record
Write-Host "[MX Records]" -ForegroundColor White
Test-DnsRecord -Label "MX record" -Type MX -Name $Domain -ExpectedContains $MailHost -Required

Write-Host ""

# SPF
Write-Host "[SPF Record]" -ForegroundColor White
Test-DnsRecord -Label "SPF" -Type TXT -Name $Domain -ExpectedContains "v=spf1" -Required

Write-Host ""

# DKIM
Write-Host "[DKIM Record]" -ForegroundColor White
Test-DnsRecord -Label "DKIM" -Type TXT -Name "dkim._domainkey.$Domain" -ExpectedContains "v=DKIM1"

Write-Host ""

# DMARC
Write-Host "[DMARC Record]" -ForegroundColor White
Test-DnsRecord -Label "DMARC" -Type TXT -Name "_dmarc.$Domain" -ExpectedContains "v=DMARC1" -Required

Write-Host ""

# PTR (reverse DNS) - can't easily check from client side
Write-Host "[PTR Record]" -ForegroundColor White
Write-Host "  PTR record for $PublicIP -> $MailHost" -ForegroundColor Gray
Write-Host "    Must be configured by ISP/hosting provider" -ForegroundColor Yellow
Write-Host "    Verify: nslookup $PublicIP" -ForegroundColor DarkGray
$warnings++

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed:   $passed" -ForegroundColor Green
Write-Host "  Warnings: $warnings" -ForegroundColor Yellow
Write-Host "  Failed:   $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

Write-Host ""
Write-Host "Required DNS records:" -ForegroundColor Cyan
Write-Host "  Type  | Name                          | Value" -ForegroundColor White
Write-Host "  A     | $MailHost                     | $PublicIP"
Write-Host "  MX    | $Domain                       | 10 $MailHost"
Write-Host '  TXT   | ' + $Domain + '                       | v=spf1 ip4:' + $PublicIP + ' include:sendcloud.net -all'
Write-Host "  TXT   | dkim._domainkey.$Domain       | (from Stalwart admin UI)"
Write-Host '  TXT   | _dmarc.' + $Domain + '                | v=DMARC1; p=quarantine; rua=mailto:postmaster@' + $Domain
Write-Host "  PTR   | $PublicIP                     | $MailHost (contact ISP)"

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "ACTION REQUIRED: Fix the failed records above before proceeding." -ForegroundColor Red
    exit 1
}
