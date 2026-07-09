param(
  [string]$EnvFile = ".env"
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

flutter build appbundle --release `
  --dart-define=SUPABASE_URL=$($vars["SUPABASE_URL"]) `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$($vars["SUPABASE_PUBLISHABLE_KEY"])
