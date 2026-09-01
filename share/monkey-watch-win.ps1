<#
monkey-watch-win.ps1 -- the SECOND monkey watcher (realisateur#782), on dexter's
WINDOWS side so that WSL2 dying cannot take the watcher with it. Granted by Zach
2026-09-01: "lets have both. Now. yes to scheduled task."

IT PRODUCES NOTHING. bin/monkey-watch.sh, inside dexter's WSL2, writes
https://hf7y.com/monkey/status.json; this reads it. Home Assistant's
sensor.monkey_watcher reads the same document on the same contract and STAYS --
"both" means both, and nothing here removes or alters it.

STALENESS IS THE DOCUMENT'S OWN, never a constant here. watcher.valid_until is
the producer's generated + cadence_minutes + grace_minutes, so changing the
producer's cadence moves this threshold with it and nothing here is edited.

DELIVERY IS TWO LEGS BECAUSE THERE ARE TWO FAILURE DOMAINS, per #782's own
table. zaxon (127.0.0.1:8643) is the estate's human channel and the only leg
that reaches Zach -- but it is served out of a WSL2 distro, so it is down in the
very case this watcher exists to outlive. The Windows event log is the leg that
always writes, so a tick that could not page anyone still leaves a record and a
non-zero Last Result. #782 gives the split: HA covers "WSL2 wedges", this covers
"HA dies", and in that second case zaxon is up. Closing the remaining gap needs
a delivery channel on the Windows side that does not transit WSL2, which is a
decision for Zach and not something to go looking for.

WHY A SECOND MECHANISM AND NOT AN EXTENSION OF ec630dd. bin/monkey-watch.sh
--install-cadence installs a crontab row inside WSL2, for ITSELF; that is the
estate's convention -- a script carries its own clock. This is a different host,
a different scheduler, and a CONSUMER rather than the producer, and its cadence
line does `cd $HOME/realisateur && git pull`, which is exactly the dependency
#782 exists to break. So the convention and the re-read discipline are reused;
the file is not.

THE INSTALLER IS bin/monkey-watch-win.sh --install-cadence --apply, and it is
bash reaching in over ssh. That is deliberate and is not a contradiction: what
RUNS must survive WSL2 being gone, what INSTALLS it need not.
#>

param([switch]$Test, [string]$Url = 'https://hf7y.com/monkey/status.json')  # -Url exercises the STALE branch against a fixture: a branch that has never fired is not a guard

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PageUrl     = 'https://hf7y.com/monkey/'
$ZaxonUrl    = 'http://127.0.0.1:8643/mcp'
$Source      = 'monkey-watch-win'
$LogName     = 'Application'
$StateDir    = Join-Path $env:ProgramData 'monkey-watch-win'
$AlertEveryH = 12
$ZaxonMax    = 110   # bin/lib/zaxon.sh: the relay REFUSES over 140 rendered chars rather than truncating, and the [from_agent] tag spends the budget

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$StateFile = Join-Path $StateDir 'last'
$AlertFile = Join-Path $StateDir 'alerted'
$RunFile   = Join-Path $StateDir 'last-run'

function Read-Line($p) { if (Test-Path $p) { "$(Get-Content $p -TotalCount 1)".Trim() } else { '' } }
function Read-Utc($s)  { [DateTime]::Parse($s, $null, 'AdjustToUniversal,AssumeUniversal') }

function Write-Log($type, $id, $text) {
  try {
    if (-not [Diagnostics.EventLog]::SourceExists($Source)) { New-EventLog -LogName $LogName -Source $Source }
    Write-EventLog -LogName $LogName -Source $Source -EventId $id -EntryType $type -Message $text
  } catch { }   # NEVER FATAL, per bin/lib/zaxon.sh: aborting because it could not record itself is worse than staying quiet
}

# The MCP handshake bin/lib/zaxon.sh performs. Loopback only: 100.107.253.56:8643
# is dexter's OWN tailnet address, which Windows cannot route to.
function Send-Zaxon($msg) {
  try {
    $acc = @{ Accept = 'application/json,text/event-stream' }
    $init = @{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2024-11-05';capabilities=@{};clientInfo=@{name=$Source;version='1'}}} | ConvertTo-Json -Depth 6 -Compress
    $r = Invoke-WebRequest -Uri $ZaxonUrl -Method POST -TimeoutSec 20 -ContentType 'application/json' -Headers $acc -Body $init -UseBasicParsing
    $sid = $r.Headers['Mcp-Session-Id']
    if (-not $sid) { return '' }
    $h = @{ Accept = 'application/json,text/event-stream'; 'mcp-session-id' = $sid }
    Invoke-WebRequest -Uri $ZaxonUrl -Method POST -TimeoutSec 20 -ContentType 'application/json' -Headers $h -UseBasicParsing `
      -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}' | Out-Null
    $call = @{jsonrpc='2.0';id=3;method='tools/call';params=@{name='ask_zach';arguments=@{question=$msg;from_agent=$Source}}} | ConvertTo-Json -Depth 6 -Compress
    $a = Invoke-WebRequest -Uri $ZaxonUrl -Method POST -TimeoutSec 30 -ContentType 'application/json' -Headers $h -Body $call -UseBasicParsing
    $m = [regex]::Match($a.Content, '"ticket_id\\?":\s*\\?"([0-9a-f]{6,})')
    if ($m.Success) { return $m.Groups[1].Value }
  } catch { }
  return ''
}

function Send-Alert($label, $why) {
  $head = "monkey-win: $label"        # `monkey-win:`, not `monkey:` -- monkey-watch.sh already speaks to Zach and he has to know which watcher did
  $room = $ZaxonMax - $head.Length - $PageUrl.Length - 2
  if ($room -lt 0) { $room = 0 }
  $short = "$why"
  if ($short.Length -gt $room) { $short = $short.Substring(0, $room) }
  $msg = "$head`n$short`n$PageUrl"
  Write-Log Error 1 "$head`n$why`n$PageUrl"
  Send-Zaxon $msg
}

$now = [DateTime]::UtcNow
$verdict = ''; $why = ''
try {
  $doc = Invoke-RestMethod -Uri $Url -TimeoutSec 30 -UseBasicParsing
  $w = $doc.watcher
  if ($now -gt (Read-Utc $w.valid_until)) {
    # Outliving its own valid_until means the PRODUCER stopped, which is not the
    # same claim as monkey being down. It hid the 2026-08-30 outage.
    $verdict = 'STALE'
    $why = "status.json is past its own valid_until $($w.valid_until) (watcher.generated $($w.generated))"
  } else {
    $verdict = "$($w.verdict)"
    $why = "$($w.why)"
  }
} catch {
  $verdict = 'UNREACHABLE'
  $why = "cannot read status.json: $($_.Exception.Message)"
}

Set-Content -Path $RunFile -Encoding ASCII -Value "$($now.ToString('yyyy-MM-ddTHH:mm:ssZ')) $verdict $why"

if ($Test) {
  $t = Send-Alert 'ALERT PATH TEST (realisateur#782)' "the live verdict right now is $verdict"
  Write-Output "monkey-watch-win: TEST alert sent; live verdict $verdict; zaxon ticket ${t}"
  exit 0
}

$bad  = @('DOWN','DEGRADED','STALE','UNREACHABLE') -contains $verdict
$last = Read-Line $StateFile
$label = ''

if ($verdict -ne $last) {
  Set-Content -Path $StateFile -Encoding ASCII -Value $verdict
  if ($verdict -eq 'PAUSED' -or ($last -eq 'PAUSED' -and $verdict -eq 'OK')) {
    $label = ''   # entering or leaving a declared pause cleanly is not a fault (mw_alert_decide, #704). PAUSED -> anything else still falls through
  } elseif ($last -ne '') {
    $label = "$last -> $verdict"
  }               # no $last is the first run ever: there is no transition to report
} elseif ($bad) {
  $lastAlert = Read-Line $AlertFile
  if ($lastAlert -eq '' -or ($now - (Read-Utc $lastAlert)).TotalHours -ge $AlertEveryH) {
    $label = "still $verdict, unread past ${AlertEveryH}h"
  }
}

if ($label -eq '') {
  Write-Output "monkey-watch-win: $verdict -- $why"
  exit 0
}

$ticket = Send-Alert $label $why
if ($ticket -ne '') {
  Set-Content -Path $AlertFile -Encoding ASCII -Value $now.ToString('yyyy-MM-ddTHH:mm:ssZ')
  Write-Output "monkey-watch-win: alerted ($label) ticket $ticket"
  exit 0
}
# Do NOT stamp $AlertFile: the next tick must retry, and a non-zero Last Result
# is what shows the failure in `schtasks /query /v`.
Write-Output "monkey-watch-win: alerted ($label) to the event log ONLY -- zaxon did not answer"
exit 1
