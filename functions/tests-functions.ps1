param(
  [string]$Project = "pablo-oviedo",
  [string]$Region  = "us-central1"
)

$BASE = "https://$Region-$Project.cloudfunctions.net"

function Send-Json {
  param([string]$Url, [hashtable]$Body)
  try {
    $json = $Body | ConvertTo-Json -Depth 6
    Write-Host "POST $Url" -ForegroundColor Cyan
    $resp = Invoke-RestMethod -Method POST -Uri $Url -ContentType 'application/json' -Body $json
    Write-Host "→ $resp" -ForegroundColor Green
  } catch {
    Write-Host "ERR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message -ForegroundColor DarkRed }
  }
}

function Test-Help {
  Send-Json -Url "$BASE/sendHelpNotification" -Body @{
    requestId    = "REQ_TEST"
    receiverId   = "USER_OWNER_ID"
    helperId     = "USER_HELPER_ID"
    helperName   = "Pablo"
    requestTitle = "Comprar agua"
  }
}

function Test-Chat {
  Send-Json -Url "$BASE/sendChatNotification" -Body @{
    chatRoomId  = "ROOM_TEST"
    senderId    = "USER_A"
    senderName  = "Pablo"
    recipientId = "USER_B"
    messageText = "¡Hola!"
  }
}

function Test-Panic {
  Send-Json -Url "$BASE/sendPanicNotification" -Body @{
    userId    = "USER_X"
    panicId   = "PANIC_TEST"
    latitude  = -25.30
    longitude = -57.64
    timestamp = (Get-Date).ToString("o")
  }
}

function Test-Rating {
  Send-Json -Url "$BASE/sendRatingNotification" -Body @{
    ratedUserId   = "USER_Y"
    requestId     = "REQ_TEST"
    raterName     = "Pablo"
    rating        = 5
    type          = "RATING"
    requestTitle  = "Comprar agua"
    requesterId   = "USER_X"             # opcional
    helperId      = "USER_HELPER_ID"     # opcional
    reviewComment = "Excelente servicio" # opcional
  }
}

function Run-All { Test-Help; Test-Chat; Test-Panic; Test-Rating }

function Open-In-Chrome {
  Start-Process "chrome.exe" "$BASE/sendHelpNotification"
  Start-Process "chrome.exe" "$BASE/sendChatNotification"
  Start-Process "chrome.exe" "$BASE/sendPanicNotification"
  Start-Process "chrome.exe" "$BASE/sendRatingNotification"
}

function Logs-Firebase([string]$fn="sendRatingNotification"){
  npx firebase functions:log --only $fn
}

function Logs-Run([string]$svc="sendratingnotification"){
  gcloud beta run services logs tail $svc --region $Region --project $Project
}
