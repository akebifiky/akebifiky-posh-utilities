<#
    .Synopsis
    その日ごとの一時的なディレクトリへのパスを出力します。

    .Description
    その日ごとの一時的なディレクトリへのパスを出力します。
    もしディレクトリが存在しない場合、新たに作成します。

    .Parameter Date
    一時的なディレクトリの日付。指定しない場合は今日の日付を用います。

    .Parameter Days
    今日の日付を基準とした相対的な日付を指定します。
    例えば -3 を指定した場合、3日前の一時ディレクトリへのパスを出力します。

    .Example
    # 本日の一時ディレクトリへのパスをクリップボードへコピーする
    tempdir | clip

    .Example
    # 3日前の一時ディレクトリを開く
    tempdir -Days -3 | ii
#>
function TempDir {
    param(
        # Date
        [Parameter(ValueFromPipeline = $True)]
        [String] $Date,

        # Provides tempdir of X days after/before
        [Int] $Days,

        # Provides tempdir of X weeks after/before
        [Int] $Weeks,

        # Provides tempdir of X months after/before
        [Int] $Months
    )

    $BaseDirectory = "${HOME}\Temporary"
    $PathFormat = "yyyy\\yyyy_MM\\yyyy_MM_dd"

    if ($Date) {
        try {
            [DateTime] $TargetDate = [DateTime] $Date
        }
        catch {
            Write-Error($_.Exception)
        }
    }
    else {
        [DateTime] $TargetDate = Get-Date
    }

    if ($Days) {
        $TargetDate = $TargetDate.AddDays($Days)
    }
    if ($Weeks) {
        $TargetDate = $TargetDate.AddDays(7 * $Weeks)
    }
    if ($Months) {
        $TargetDate = $TargetDate.AddMonths($Months)
    }
    
    $TargetDirectory = ${BaseDirectory} + "\" + $TargetDate.ToString($PathFormat)
    if (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory $TargetDirectory
    }
    return $TargetDirectory
}
Export-ModuleMember -Function TempDir

<#
    .Synopsis
    管理者権限でコマンドを実行します。

    .Description
    管理者権限でコマンドを実行するか、コマンドが指定されない場合PowerShellを管理者権限で開きます。
    この関数はすべての引数をコマンドとして認識します。
    なお、コマンドの実行には pwsh.exe が利用されるものとします。

    .Example
    # Install the latest Python with Chodolatey
    sudo choco install python
#>
function SuDo {
    param(
        # Execute silently
        [Switch]
        $Silent
    )

    if ($Args.Count -gt 0) {
        $CurrentDirectory = (Get-Location).Path
        $Commands = "Set-Location $CurrentDirectory; Write-Host `"[Administrator] $CurrentDirectory> $args`"; $args;"
        if (!$Silent) {
            $Commands += "Pause;"
        }
        $Commands += "exit;"
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($Commands)
        $EncodedCommand = [Convert]::ToBase64String($bytes)

        if ($Silent) {
            Start-Process pwsh.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-encodedCommand", $EncodedCommand
        } else {
            Start-Process pwsh.exe -Verb RunAs -ArgumentList "-NoExit", "-encodedCommand", $EncodedCommand
        }
    }
    else {
        Start-Process pwsh.exe -Verb RunAs
    }
}
Export-ModuleMember -Function SuDo


<#
    .Synopsis
    ローカルサーバーへのホスト名をリストアップしたファイルをもとに、各ホスト名がWSLのIPアドレスへ解決されるよう hosts ファイルを更新します。

    .Parameter Path
    ホスト名をリストアップしたファイル。
    当該ファイルは、1行に1つホスト名が記載されていることを想定する。

    .Example
    Update-WSL-Hosts hostnames.txt
#>
function Update-WSL-Hosts {
    param(
        # Path to the file that is list of hostnames
        [Parameter(ValueFromPipeline = $True)]
        [String]
        $Path
    )
    if (!$Path) {
        Write-Error "Please specify the path to file containing list of hostnames!"
        return;
    }
    if (!(Test-Path -Path $Path -PathType Leaf)) {
        Write-Error "The path $Path does not exist."
        return;
    }

    $HostsFile = "C:\Windows\System32\drivers\etc\hosts"
    $Hostnames = Get-Content $Path | Select-String -Pattern "^\s*#.*" -NotMatch
    $HostnamePattern = "($([String]::Join("|", $Hostnames)))".Replace("\.", "\.")
    $HostsFileContent = Get-Content $HostsFile | Select-String -Pattern $HostnamePattern -NotMatch
    $WSLAddress = "$(wsl hostname -I)".Split(" ")[0]

    Write-Host "Hostname source: $Path"
    Write-Host "Resolved WSL IP: $WSLAddress"
    $Hostnames | ForEach-Object { $HostsFileContent += "$WSLAddress    $_" }
    [String]::Join([System.Environment]::NewLine, $HostsFileContent) | Out-File $HostsFile -NoNewline
    Write-Host "Updated hosts successfully."
}
Export-ModuleMember -Function Update-WSL-Hosts