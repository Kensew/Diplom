$addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object {
    $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' -and
    $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL|VirtualBox|VMware|Hyper-V'
  } |
  Sort-Object InterfaceMetric

if ($addresses -and $addresses.Count -gt 0) {
  Write-Output $addresses[0].IPAddress
  exit 0
}

foreach ($line in (ipconfig)) {
  if ($line -match 'IPv4[^:]*:\s*(\d+\.\d+\.\d+\.\d+)') {
    $ip = $Matches[1]
    if ($ip -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)') {
      Write-Output $ip
      exit 0
    }
  }
}

Write-Output '127.0.0.1'
