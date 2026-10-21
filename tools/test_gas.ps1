$url = "https://script.google.com/macros/s/AKfycbyiU9eX7H-d4PUToq2laCsLiEwpmevQUiIHydURzfBkpF9xyxHW4Pczwm4uhVJhYUtT/exec"
$res = Invoke-WebRequest -Uri $url -Method Get -MaximumRedirection 5
Write-Host "StatusCode: $($res.StatusCode)"
Write-Host "Raw Content:"
Write-Host $res.Content.Substring(0, [math]::Min(500, $res.Content.Length))
