Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lucadruda/iotc-solution-migrator/main/deployments/scripts/config.sh" -OutFile /tmp/config.sh

bash /tmp/config.sh

# Setup SQL Server
# Connect-AzAccount -Identity
# Install-Module -Name SqlServer -Force
# Import-Module -Name SqlServer
# $token = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token
# $sqlStatements = @()
# $sqlStatements += "CREATE USER `"$Env:IDENTITY_NAME`" FROM external provider"
# $sqlStatements += "exec sp_addrolemember 'db_owner', `"$ENV:IDENTITY_NAME`""
# $query = $sqlStatements -join ";"
# Invoke-Sqlcmd -ServerInstance $Env:SQL_ENDPOINT -Database $Env:SQL_DATABASE -AccessToken "$token" -Query $query
