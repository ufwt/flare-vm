###########################################
#
# FLARE VM Installation Script
#
# To execute this script:
#   1) Open powershell window as administrator
#   2) Allow script execution by running command "Set-ExecutionPolicy Unrestricted"
#   3) Execute the script by running ".\install.ps1"
#
###########################################

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )

if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

# https://stackoverflow.com/questions/11696944/powershell-v3-invoke-webrequest-https-error
# Allows current PowerShell session to trust all certificates
# Also a good find: https://www.briantist.com/errors/could-not-establish-trust-relationship-for-the-ssltls-secure-channel/
  Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
  
  try {
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
  } catch {
    Write-Debug "Failed to find SSL type...1"
  }
  try {
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls'
  } catch {
    Write-Debug "Failed to find SSL type...2"
  }
  
  $prevSecProtocol = [System.Net.ServicePointManager]::SecurityProtocol
  $prevCertPolicy = [System.Net.ServicePointManager]::CertificatePolicy
  
  Write-Host "[ * ] Installing Boxstarter"
  # Become overly trusting
  [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
  [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
  iex ((New-Object System.Net.WebClient).DownloadString('http://boxstarter.org/bootstrapper.ps1')); get-boxstarter -Force
  # Restore previous trust settings for this PowerShell session
  # Note: SSL certs trusted from installing BoxStarter above will be trusted for the remaining PS session
  [System.Net.ServicePointManager]::SecurityProtocol = $prevSecProtocol
  [System.Net.ServicePointManager]::CertificatePolicy = $prevCertPolicy

  # Boxstarter options
  $Boxstarter.RebootOk=$true # Allow reboots?
  $Boxstarter.NoPassword=$false # Is this a machine with no login password?
  $Boxstarter.AutoLogin=$true # Save my password securely and auto-login after a reboot
  Set-BoxstarterConfig -NugetSources "https://www.myget.org/F/flare/api/v2;https://chocolatey.org/api/v2" -LocalRepo "."

  # Go ahead and disable the Windows Updates
  Disable-MicrosoftUpdate

  # Get user credentials for autologin during reboots
  Write-Host "[ * ] Getting user credentials ..."
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name "ConsolePrompting" -Value $True
  $cred=Get-Credential $env:username

  # Needed for many applications
  cinst -y vcredist-all

  if ($cred) {
      Install-BoxstarterPackage -PackageName flarevm.installer.flare -Credential $cred
  } else {
      Install-BoxstarterPackage -PackageName flarevm.installer.flare
  }

} else {
  Write-Host "[ERR] Please run this script as administrator"
  Read-Host  "      Press ANY key to continue..."
}