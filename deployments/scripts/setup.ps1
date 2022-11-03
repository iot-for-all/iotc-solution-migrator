apt-get update
apt-get install -y curl git jq

curl -fsSL https://deb.nodesource.com/setup_lts.x | bash
apt-get install -y nodejs

node -v
npm -v

# Install func tools
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
apt-get update
apt-get install -y azure-functions-core-tools-4

# Setup SQL Server
# Connect-AzAccount -Identity

Install-Module -Name SqlServer -Force
Install-Module Az.DeviceProvisioningServices
Import-Module -Name SqlServer
Import-Module -Name Az.DeviceProvisioningServices

# Create enrollment group
Add-AzIoTDeviceProvisioningServiceEnrollmentGroup -ResourceGroupName $Env:RESOURCE_GROUP -DpsName $Env:DPS_RESOURCE_NAME -Name $Env:DPS_ENROLLMENT_NAME -AttestationType SymmetricKey -PrimaryKey $Env:DPS_ENROLLMENT_PRIMARY_KEY -SecondaryKey $Env:DPS_ENROLLMENT_SECONDARY_KEY

# $token = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token
$sqlStatements = @()
$sqlStatements += "CREATE USER grafana WITH PASSWORD='$Env:GRAFANA_PASSWORD'"
$sqlStatements += "GRANT CONNECT TO grafana"
$sqlStatements += "GRANT SELECT TO grafana"
$query = $sqlStatements -join ";"
# Invoke-Sqlcmd -ServerInstance $Env:SQL_ENDPOINT -Database $Env:SQL_DATABASE -AccessToken "$token" -Query $query
