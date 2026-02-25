<#
.SYNOPSIS
  Deploy Stalwart Mail Server to K3s cluster.
.DESCRIPTION
  Deploys Stalwart K8s manifests and verifies the deployment.
  Run from the lurus-webmail root directory.
.EXAMPLE
  .\scripts\deploy-stalwart.ps1
  .\scripts\deploy-stalwart.ps1 -AdminPassword "your-secure-password"
#>

param(
    [string]$AdminPassword = "",
    [string]$MasterNode = "100.98.57.55",
    [string]$SshUser = "root"
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$StalwartDir = Join-Path $ScriptRoot "k8s/stalwart"

Write-Host "=== Stalwart Mail Server Deployment ===" -ForegroundColor Cyan

# Step 1: Update admin password if provided
if ($AdminPassword) {
    Write-Host "[1/5] Updating admin password in secret.yaml..." -ForegroundColor Yellow
    $secretFile = Join-Path $StalwartDir "secret.yaml"
    $content = Get-Content $secretFile -Raw
    $content = $content -replace 'STALWART_ADMIN_PASSWORD: "changeme"', "STALWART_ADMIN_PASSWORD: `"$AdminPassword`""
    Set-Content -Path $secretFile -Value $content -NoNewline
    Write-Host "  Admin password updated." -ForegroundColor Green
} else {
    Write-Host "[1/5] No admin password provided, using existing value." -ForegroundColor Yellow
}

# Step 2: Apply Stalwart namespace and resources
Write-Host "[2/5] Applying Stalwart K8s manifests..." -ForegroundColor Yellow
ssh "${SshUser}@${MasterNode}" "kubectl apply -k -" < (Get-Content (Join-Path $StalwartDir "kustomization.yaml") -Raw | Set-Content -Path "$env:TEMP\stalwart-kustomize.yaml" -PassThru)

# Use direct kubectl apply instead
$yamlFiles = @("namespace.yaml", "secret.yaml", "configmap.yaml", "pvc.yaml", "service.yaml", "statefulset.yaml")
foreach ($file in $yamlFiles) {
    $filePath = Join-Path $StalwartDir $file
    Write-Host "  Applying $file..." -ForegroundColor Gray
    Get-Content $filePath -Raw | ssh "${SshUser}@${MasterNode}" "kubectl apply -f -"
}
Write-Host "  All manifests applied." -ForegroundColor Green

# Step 3: Wait for Stalwart pod to be ready
Write-Host "[3/5] Waiting for Stalwart pod to be ready..." -ForegroundColor Yellow
$maxRetries = 30
$retryCount = 0
while ($retryCount -lt $maxRetries) {
    $status = ssh "${SshUser}@${MasterNode}" "kubectl get pods -n mail -l app=stalwart -o jsonpath='{.items[0].status.phase}' 2>/dev/null"
    if ($status -eq "Running") {
        Write-Host "  Stalwart pod is running." -ForegroundColor Green
        break
    }
    $retryCount++
    Write-Host "  Waiting... ($retryCount/$maxRetries) Status: $status" -ForegroundColor Gray
    Start-Sleep -Seconds 10
}

if ($retryCount -eq $maxRetries) {
    Write-Host "  WARNING: Stalwart pod did not reach Running state within timeout." -ForegroundColor Red
    ssh "${SshUser}@${MasterNode}" "kubectl describe pods -n mail -l app=stalwart"
    exit 1
}

# Step 4: Verify services
Write-Host "[4/5] Verifying services..." -ForegroundColor Yellow
ssh "${SshUser}@${MasterNode}" "kubectl get svc -n mail"
ssh "${SshUser}@${MasterNode}" "kubectl get pods -n mail -o wide"

# Step 5: Apply webmail updates (TCP routes + updated configs)
Write-Host "[5/5] Applying webmail namespace updates..." -ForegroundColor Yellow
$webmailFiles = @("mail-tcp-routes.yaml")
foreach ($file in $webmailFiles) {
    $filePath = Join-Path $ScriptRoot "k8s" $file
    if (Test-Path $filePath) {
        Write-Host "  Applying $file..." -ForegroundColor Gray
        Get-Content $filePath -Raw | ssh "${SshUser}@${MasterNode}" "kubectl apply -f -"
    }
}

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Configure DNS records (run .\scripts\verify-dns.ps1)"
Write-Host "  2. Create initial admin account via Stalwart web UI:"
Write-Host "     ssh $SshUser@$MasterNode kubectl port-forward -n mail svc/stalwart 8080:8080"
Write-Host "     Then open http://localhost:8080"
Write-Host "  3. Update webmail secrets with real SendCloud credentials"
Write-Host "  4. Restart webmail worker: kubectl rollout restart deployment/webmail-worker -n lurus-webmail"
