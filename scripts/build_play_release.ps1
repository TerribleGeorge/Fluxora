param(
  [string]$EnvFile = ".env",
  [string]$PublicBookingBaseUrl = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $EnvFile)) {
  throw "Arquivo de ambiente não encontrado: $EnvFile"
}

$vars = @{}
Get-Content $EnvFile |
  Where-Object { $_ -and -not $_.TrimStart().StartsWith("#") } |
  ForEach-Object {
    $parts = $_ -split "=", 2
    if ($parts.Length -eq 2) {
      $vars[$parts[0].Trim()] = $parts[1].Trim()
    }
  }

if (-not $vars.ContainsKey("SUPABASE_URL") -or [string]::IsNullOrWhiteSpace($vars["SUPABASE_URL"])) {
  throw "SUPABASE_URL ausente em $EnvFile"
}

if (-not $vars.ContainsKey("SUPABASE_PUBLISHABLE_KEY") -or [string]::IsNullOrWhiteSpace($vars["SUPABASE_PUBLISHABLE_KEY"])) {
  throw "SUPABASE_PUBLISHABLE_KEY ausente em $EnvFile"
}

$buildArguments = @(
  "build",
  "appbundle",
  "--release",
  "--dart-define=SUPABASE_URL=$($vars["SUPABASE_URL"])",
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($vars["SUPABASE_PUBLISHABLE_KEY"])"
)

$resolvedPublicBookingBaseUrl = $PublicBookingBaseUrl
if ([string]::IsNullOrWhiteSpace($resolvedPublicBookingBaseUrl) -and
    $vars.ContainsKey("PUBLIC_BOOKING_BASE_URL")) {
  $resolvedPublicBookingBaseUrl = $vars["PUBLIC_BOOKING_BASE_URL"]
}

if (-not [string]::IsNullOrWhiteSpace($resolvedPublicBookingBaseUrl)) {
  $buildArguments += "--dart-define=PUBLIC_BOOKING_BASE_URL=$resolvedPublicBookingBaseUrl"
}

if ($vars.ContainsKey("AUTH_WEB_REDIRECT_BASE_URL") -and
    -not [string]::IsNullOrWhiteSpace($vars["AUTH_WEB_REDIRECT_BASE_URL"])) {
  $buildArguments += "--dart-define=AUTH_WEB_REDIRECT_BASE_URL=$($vars["AUTH_WEB_REDIRECT_BASE_URL"])"
}

flutter @buildArguments
