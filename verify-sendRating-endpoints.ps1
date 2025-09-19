# === verify-sendRating-endpoints.ps1 ===
# Prueba sendRatingNotification en LOCAL (emulador) y, si definís PROD_ENDPOINT, también en PRODUCCIÓN.

$LocalEndpoint = "http://127.0.0.1:5002/pablo-oviedo/us-central1/sendRatingNotification"
$ProdEndpoint  = $env:SENDRATING_ENDPOINT  # opcional: setearlo antes:  $env:SENDRATING_ENDPOINT="https://us-central1-pablo-oviedo.cloudfunctions.net/sendRatingNotification"

function Test-Endpoint {
  param([string]$Name, [string]$Endpoint)

  if (-not $Endpoint) { Write-Host "[$Name] Sin endpoint, salto." -ForegroundColor Yellow; return }

  Write-Host "`n===== Probando $Name =====" -ForegroundColor Cyan
  Write-Host "Endpoint: $Endpoint"

  $ok = @{
    type="RATING"; requestId="REQ_$Name"; requestTitle="Comprar agua"; rating=5;
    reviewComment="Excelente servicio"; raterName="Pablo"; requesterId="USER_X";
    helperId="USER_HELPER_ID"; ratedUserId="USER_Y"
  } | ConvertTo-Json -Depth 5

  $bad = @{ type="RATING"; requestId="REQ_ERR_$Name" } | ConvertTo-Json

  Write-Host "`n-- OK request --" -ForegroundColor Green
  try {
    $respOk = Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType "application/json" -Body $ok -TimeoutSec 30
    $respOk | ConvertTo-Json -Depth 10
  } catch {
    Write-Host "ERROR (OK request):" -ForegroundColor Red
    if ($_.Exception.Response) {
      $r = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $r.BaseStream.Position=0; $r.DiscardBufferedData(); $r.ReadToEnd() | Write-Host
    } else { Write-Host $_ }
  }

  Write-Host "`n-- BAD request (faltantes) --" -ForegroundColor Yellow
  try {
    Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType "application/json" -Body $bad -TimeoutSec 30
  } catch {
    if ($_.Exception.Response) {
      $r = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $r.BaseStream.Position=0; $r.DiscardBufferedData()
      $err = $r.ReadToEnd()
      Write-Host $err
    } else { Write-Host $_ }
  }
}

# Ejecutar pruebas
Test-Endpoint -Name "LOCAL" -Endpoint $LocalEndpoint
Test-Endpoint -Name "PROD"  -Endpoint $ProdEndpoint
