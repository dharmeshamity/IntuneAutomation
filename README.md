# This document is a user guide on how to execute script

### **OS Compatibility:** Compatible on Windows, masOS (Not tested, but I believe it should work) and Linux. 

### **Prerequisite**
* **Powershell Core 7.0 or higher:** Please download and install powershell core. The script is compatible with Powershell Core (*Not Windows Powershell*). 

    * *Windows:* https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7
    * *macOS:* https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7
    * *Linux:* https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7

### **Running the scripts**
1. Click **Clone or download** button  you will see either to clone or download this project repository. If you are familiar with git tools, go ahead and clone, if not download the code. This will download the code as zip file. Extract the code to the folder or your choice. *Step #3 and #4 need to be done only first time you run this Automation script*
2. open powershell core by running ***pwsh*** command. This will open powershell core shell. 
3. **Unblock powershell scripts:** cd into the directory where you extracted the code. Run Following command: <pre>Get-Item -Path *.ps1 | Unblock-File</pre>
4. Type command: <pre>Get-ExecutionPolicy</pre> Check the output. If this command output *Restricted* or *AllSigned*, you will need to follow instructions to set the execution policy to *RemoteSigned* or *UnRestricted*. Reach out to me if you need help. Instructions: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7
5. **Custom Configuratioon:** In Notepad or json or Text Editor or your choice open: appsettings.PRODUCTION.json file. Update the configuration according to you liking.
<pre><code>
{
    "SourceFolderPath": {Pathto folder where you will drop data files},
    "SourceCSVDemiliter": {Do not touch if source files are csv files},
    "SourceFileExtention": {Do not touch if source files are csv files},
    "ArchiveFolderPath": {Path to folder where you will script will archive source files},
    "ResultFolderPath": {Path to folder where automation script put results},
    "MSGraphApiAuthenticationEndpoint": {DO_NOT_TOUCH. This is endpoint for creating token for interacting with Graph APIs}, 
    "MSGraphApiClientId": {Provide the ClientId for the production graph apis},
    "MSGraphApiIntuneDeviceManagementEndpoint": {DO_NOT_TOUCH. This is endpoint for Graph APIs}
}
</code></pre>
6. **Execution:** Run following command on the pwsh prompt *NOTE: change \ will be / if running on mac or Linux
<pre>.\Invoke-IntuneDeviceAutomation.ps1 -Environment PRODUCTION</pre>
*First time when you run this, the script will ask for credentials to connect to graph api and securely store encrypted credentials on your computer. If you need to change those credentials run following, which will ask for credentials again*
<pre>.\Invoke-IntuneDeviceAutomation.ps1 -Environment PRODUCTION -RefreshCredentials</pre>
7. If the execution runs as expected, you should see the script output information for each device in yor source file and tells you what if it was successful or unsuccessful *All these logs are also stored in the log file which will also outputed.* Finally it will show you the Results file location and archive file location. The result file will have result of each device id which the script tried to update and lets you know if successful or unsuccessful.
<br/>
*Below is a sample output:
<pre>
**********************
PowerShell transcript start
Start time: 20200316140644
**********************
Transcript started, output file is C:\Users\dharmesh_pariawala\AppData\Local\IntuneAutomation\20200316-140644.8060.log
Begin
WARNING: Saved new credentials to C:\Users\dharmesh_pariawala\AppData\Local\IntuneAutomation\credentials\msgraphapi-credentials.DEV.json
Reading the MS Graph API Credential file
Processing File 1 of 1..
Currently processing file: imei..csv
Managed Owner Type: company
Device Id: 692b32a4-ad46-4928-9934-87196ff4042b is managed by company. No actions will be taken
WARNING: Device Id: 3bc08269-4bcf-43c8-9dfe-35ee3a5b477b not found
Managed Owner Type: company
Device Id: 4212fac4-7cc2-4fed-b9ee-588abeef4c01 is managed by company. No actions will be taken
Managed Owner Type: company
Device Id: 9c1ddc41-5db0-458a-80e3-2375d0404ea3 is managed by company. No actions will be taken
Managed Owner Type: company
Device Id: 18bd6d06-f8ad-49ea-a24e-6fbcf72b4fa2 is managed by company. No actions will be taken
Managed Owner Type: company
Device Id: e27aa111-fa27-45fd-94d9-94c4864c2d1d is managed by company. No actions will be taken
Managed Owner Type: company
Device Id: 407524ec-bca1-4d1c-91c2-19c895fd3ecd is managed by company. No actions will be taken
Exporting Results
Exporting results to file: C:\work\Applications\IntuneAutomation\ResultFiles\results-imei.-20200316-140644.8060.csv
Moving the source file to archive folder. Archive FileName: C:\work\Applications\IntuneAutomation\ArchiveFiles\archive-imei.-20200316-140644.8060..csv
Done..
**********************
PowerShell transcript end
End time: 20200316140704
</pre>
8. Check the results. 