Invoke-WebRequest -Uri "https://deb.nodesource.com/setup_lts.x" -OutFile /tmp/config.sh

bash /tmp/config.sh

# Setup SQL Server

Install-Module -Name SqlServer -Force
Import-Module -Name SqlServer
$token = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token
$sqlStatements = @()
$sqlStatements += "CREATE USER `"$Env:IDENTITY_NAME`" FROM external provider"
$sqlStatements += "exec sp_addrolemember 'db_owner', `"$ENV:IDENTITY_NAME`""
$query = $sqlStatements -join ";"
Invoke-Sqlcmd -ServerInstance $Env:SQL_ENDPOINT -Database $Env:SQL_DATABASE -AccessToken "$token" -Query $query
