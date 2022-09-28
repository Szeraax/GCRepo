param(
    $Path = "$PSScriptRoot\output"
)
$baseUri = "https://www.churchofjesuschrist.org"
foreach ($year in 2022..2000) {
    foreach ($month in "10", "04") {
        $page = [System.Net.WebClient]::new().DownloadString("$baseUri/study/general-conference/$year/$month")
        if ([string[]]$links = [regex]::Matches($page, 'href="(/study/general-conference/\d+/\d+/\w+)"').groups | Where-Object name -EQ 1 | Where-Object { $_ -notmatch "video" }) {
            $links | ForEach-Object -Parallel {
                $opt = Invoke-RestMethod "$using:baseUri/study/api/v3/language-pages/type/content?lang=eng&uri=$($_ -replace "/study")"
                $obj = [PSCustomObject]@{
                    speaker     = ($opt.content.body -split "`n" | Select-String author-name) -replace "<.*?>" -replace "^By "
                    title       = $opt.content.head.'page-meta-social'.pageMeta.title
                    description = $opt.content.head.'page-meta-social'.pageMeta.description
                    body        = $opt.content.body -replace "<.*?>" -split "`n" | ForEach-Object Trim | Where-Object { $_ }
                    audio       = $opt.meta.audio[0].mediaUrl
                    pdf         = $opt.meta.pdf.source
                    link        = "$using:baseUri/$_"
                    sorting     = $_ -replace ".*/"
                }
                $folder = "$using:Path\$using:year-$using:month"
                mkdir -ea silent $folder | Out-Null
                $obj | ConvertTo-Json | Out-File "$folder\$($obj.sorting).json" -Force
            }
        }
    }
}
