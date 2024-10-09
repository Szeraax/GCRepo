[CmdletBinding()]
param(
    $Path = "$PSScriptRoot\output",
    # We should always check all of the last 10 years if no years specified
    [int[]]$YearList = (((Get-Date).year)..((Get-Date).year - 10)),
    [string[]]$MonthList = ("10", "04")
)
$baseUri = "https://www.churchofjesuschrist.org"
$totalCheck = $YearList.Count * $MonthList.Count
$i = 0
foreach ($year in $YearList) {
    foreach ($month in $MonthList) {
        Write-Progress -Activity Scraping -Status "Checking $year-$month now" -PercentComplete ($i / $totalCheck * 100)
        $page = [System.Net.WebClient]::new().DownloadString("$baseUri/study/general-conference/$year/$month")
        if ([string[]]$links = [regex]::Matches($page, 'href="(/study/general-conference/\d+/\d+/[\w-]+)').groups | Where-Object name -EQ 1 | Sort-Object -Unique | Where-Object { $_ -notmatch "video" }) {
            "links present $year ${month}: $($links.count)" | Write-Verbose
            $links | ForEach-Object -Parallel {
                $link = $_
                $opt = Invoke-RestMethod "$using:baseUri/study/api/v3/language-pages/type/content?lang=eng&uri=$($_ -replace "/study")"
                try {
                    $obj = [PSCustomObject]@{
                        speaker     = ($opt.content.body -split "`n" | Select-String author-name) -replace "<.*?>" -replace "^By "
                        title       = $opt.content.head.'page-meta-social'.pageMeta.title
                        description = $opt.content.head.'page-meta-social'.pageMeta.description
                        body        = $opt.content.body -replace "<.*?>" -split "`n" | ForEach-Object Trim | Where-Object { $_ }
                        audio       = if ($opt.meta.audio) { $opt.meta.audio[0].mediaUrl }
                        pdf         = $opt.meta.pdf.source
                        link        = "$using:baseUri/$_" -replace "//", "/"
                        sorting     = $_ -replace ".*/"
                    }
                }
                catch {
                    "error processing $link" | Write-Host
                }
                $folder = "$using:Path\$using:year-$using:month"
                if ($_ -match "-session") {
                    $folder = "$using:Path-sessions\$using:year-$using:month"
                }
                mkdir -ea silent $folder | Out-Null
                $obj | ConvertTo-Json | Out-File "$folder\$($obj.sorting).json" -Force
            }
        }
        $i++
    }
    Write-Progress -Activity Scraping -Completed
}
