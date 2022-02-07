<#
.PREREQUSITE
 Deploy terraform infrastructure code.

.DESCRIPTION 
 Install IIS service to server0 & server1.

.NOTES
 Adjust variables in declaration accordingly if terraform resource names are edited. 
 Written by Marko Sabljic
 on Feb 2022.
#>

#Declaration
$rg="Assignment1"
$loc="Canadaeast"
$Vnet = "Vnet1"

#Updates extension properties or adds an extension to a virtual machine.
#https://docs.microsoft.com/en-us/powershell/module/az.compute/set-azvmextension?view=azps-7.1.0

 $ServerList=('Server0','Server1') `

   Foreach ($Server in $ServerList) `
        {Set-AzVMExtension `
        -ResourceGroupName $rg `
        -Name IIS `
        -VMName $Server `
        -Location $loc `
        -Publisher Microsoft.Compute `
        -ExtensionType CustomScriptExtension `
        -TypeHandlerVersion 1.8 `
        -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\default.htm\" -Value $($env:computername)"}'
        }
        #end for each