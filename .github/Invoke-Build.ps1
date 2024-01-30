param (
    [Parameter(Position = 0)][string]$inputFilename = "./lists.yml",
    [Parameter(Position = 1)][string]$readmeFilename = "./readme.md"
)

function Invoke-LoadModule ($m) {
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object { $_.Name -eq $m }) {
        return $true
    }

    # If module is not imported, but available on disk then import
    if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $m }) {
        Import-Module $m -Verbose
        return $true
    }

    # If module is not imported, not available on disk, but is in online gallery then install and import
    if (Find-Module -Name $m | Where-Object { $_.Name -eq $m }) {
        Install-Module -Name $m -Force -Verbose -Scope CurrentUser
        Import-Module $m -Verbose
        return $true
    }

    # If the module is not imported, not available and not in the online gallery then abort
    Write-Host "`e[31m!`e[0m Module $m is not imported, not available and not in the online gallery!"
    EXIT 1
}

function Validate-Entry($obj) {
    if (!$obj) {
        Write-Host "`e[31m!`e[0m Something went wrong"
        EXIT 1
    }

    if (!$obj.ContainsKey("link")) {
        Write-Host "`e[31m!`e[0m Link was not provided for the object"
        EXIT 1
    }
    
    if (!$obj.ContainsKey("name")) {
        Write-Host "`e[31m!`e[0m Name was not provided for the object"
        EXIT 1
    }
}

function Extract-FileName($obj) { 
    $linkParts = $obj["link"].Split("/")
    $linkParts = $linkParts | Where-Object { $_ -ne "" }
    return "hosts-$($linkParts[-2]).txt"
}

function Format-Link($obj, $imageSize = 1.0) {
    $str = ""

    # Handle logo
    if ($obj.ContainsKey("logo")) {
        $str += "<img src=`"$($obj["logo"])`" alt=`"`" style=`"height: $($imageSize)rem;`" /> "
    }

    if ($obj.ContainsKey("name")) {
        $str += $($obj["name"])
    }
    else {
        $str += "Hosts"
    }

    # Handle link
    $str = "- [**$str**]($($obj["link"]))"

    return $str
}

function Process-Link($name, $link, $filename) {
    Write-Host -NoNewline " - `e[33m$name`e[0m ($link)"

    $lines = 0

    $response = Invoke-WebRequest -Uri $link -UseBasicParsing
    $data = $response.Content -split '\r?\n' -ne ''

    foreach ($line in $data) {
        if (-not ($line -match '^#.*')) {
            "0.0.0.0 $line" | Add-Content -Path $filename
            $lines++
        }
        else {
            $line | Add-Content -Path $filename
        }
    }
    
    # Normalize line endings
    $text = [IO.File]::ReadAllText($filename) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($filename, $text)
    
    Write-Host " -> `e[33m$filename`e[0m"

    return $lines
}

function Process-Hosts($obj) {
    Validate-Entry $obj

    $filename = Extract-FileName $obj
    $lines = Process-Link $obj["name"] $obj["link"] $filename

    $str += "`n"
    $str += "$(Format-Link $obj)"
    $str += "`n`n"
    $str += "  - [$filename](https://raw.githubusercontent.com/C010UR/adaway-hosts-converter/main/$filename)"
    $str += "<br>`n"
    $str += "  - $lines host"
    
    if ($lines -gt 1) {
        $str += 's'
    }

    $str += "`n"

    return $str
}

if (!(Invoke-LoadModule "powershell-yaml")) {
    EXIT 1
}

Remove-Item -Path "./hosts-*.txt" -Force -ErrorAction SilentlyContinue
Remove-Item -Path $readmeFilename -Force -ErrorAction SilentlyContinue

# Get yaml
$yml = Get-Content $inputFilename | ConvertFrom-Yaml

# Resulting string
$md = ""

# Header
$md += "# 🛡 AdAway hosts converter"
$md += "`n`n"
$md += "## 🕒 Updated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
$md += "`n`n"
$md += "## 🗒 Hosts lists"
$md += "`n"

$md += ($yml.lists | ForEach-Object { Process-Hosts $_ }) -join ""

Out-File -FilePath $readmeFilename -InputObject $md

# Normalize line endings
$text = [IO.File]::ReadAllText($readmeFilename) -replace "`r`n", "`n"
[IO.File]::WriteAllText($readmeFilename, $text)