param(
    [string] $SubscriptionId
    [string] $ResourceGroup
    [string] $EnrollmentGroupName
    [string] $PrimaryKey
    [string] $SecondaryKey
    [string] $DpsName
    [string] $FunctionPrincipal
)

Connect-AzAccount -Identity
Install-Module Az.DeviceProvisioningServices -Force
Install-Module SQLServer -Force
Select-AzSubscription -Subscription $subscriptionId


Add-AzIoTDeviceProvisioningServiceEnrollmentGroup -ResourceGroupName $ResourceGroup -Name $EnrollmentGroupName -AttestationType SymmetricKey -PrimaryKey "$PrimaryKey" -SecondaryKey "$SecondaryKey" -DpsName "$DpsName"

# SQL setup
Import-Module SQLServer
