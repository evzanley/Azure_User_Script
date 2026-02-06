#Usage without Solarwinds Service Desk .\AddUser.ps1 -FirstName Fore -LastName Last -Password password -Dept Fake -City Exampletown -Country Country -Phone 3333333333 -Title JobTitle -ReferenceUser olduser@domain.com -Domain domain.com
#Usage with Solarwinds Service Desk: .\AddUser.ps1 -Incident <find_incident_number_From_url> -Apikey <find_your_json_key>

param (
    	[string]$FirstName,
	[string]$LastName,
	[string]$Password,
	[string]$Dept,
	[string]$City,
	[string]$UPN,
	[string]$Phone,
	[string]$Title,
	[string]$ReferenceUser,
	[string]$Domain
)

if (-not $Password) {$Password = "welcome"}
if (-not $ReferenceUser) {$ReferenceUser = "no-reply@$($DomainName)"}
$UPN_A = ""

#Prepare the log file
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = ".\AddUser_$($timestamp).txt"

#Connect to Service Desk
if ($Incident -ne $null) {
	Write-Host "Gathering data from Solarwinds ServiceDesk..."
	if (-not $Apikey) {$Apikey = "" ; Write-Warning "Warning: An Incident Number was entered but the -Apikey was not specified. No info will be auto-populated." }
	$header_params = @{"X-Samanage-Authorization" = "Bearer $($Apikey)"
	'Accept' = 'application/json'}
	$raw_request = Invoke-RestMethod -Uri "https://api.samanage.com/incidents/$($Incident)" -Headers $header_params
	$cust = $raw_request.custom_fields_values

	#This part of the loop expects a text file with seven comma separated integers. These will correspond to the values in your JSON input.
	#Some experimentation may be required with your specific organization to get them right.
	$filePath = "field_indices.txt"

	# Read file content
	$raw = Get-Content -Path $filePath

	# Split on whitespace or commas (supports 1-per-line, space-separated, or CSV)
	$tokens = $raw -split '[,\s]+' | Where-Object { $_ -ne "" }

	# Validate that all tokens are integers
	if (-not ($tokens | ForEach-Object { $_ -match '^-?\d+$' } | Where-Object { $_ -eq $false } | Measure-Object).Count -eq 0) {
		"No field index file available. Will not attempt to get values through API." | Out-File -Append -FilePath $logFile
	}
	else {
			$numbers = $tokens | ForEach-Object { [int]$_ } #Convert strings ti ints

			#Separating these into separate, named variables for visual clarity.
			$EMPLOYEE_NAME_INDEX = $numbers[0]
			$JOBTITLE_INDEX = $numbers[1]
			$CITY_INDEX = $numbers[2]
			$DEPT_INDEX = $numbers[3]
			$COUNTRY = $numbers[4]
			$PHONE_IND = $numbers[5]
			$EMAIL_ADDR_IND = $numbers[6]

			$cust = $raw_request.custom_fields_values
			$Employee_Name_data = $cust[$EMPLOYEE_NAME_INDEX]
			$Job_Title_data = $cust[$JOBTITLE_INDEX]
			$City_data = $cust[$CITY_INDEX]
			$Country_data = $cust[$COUNTRY_INDEX]
			$Dept_data = $cust[$DEPT_INDEX]
			$Phone_data = $cust[$PHONE_IND]
			$Preferred_Email_data = $cust[$EMAIL_ADDR_IND]
			
			"Attempting to pull the following fields from Solarwinds Service Desk:" | Out-File -Append -FilePath $logFile
			#Split firstname and lastname
			$DisplayName = $Employee_Name_data.value 
			$SplitName = $DisplayName.split(' ')
			$FirstName = $SplitName[0] ; $LastName = $SplitName[1]
			$Title = $Job_Title_data.value 
			$Phone = $Phone_data.value 
			$UPN_A = $Preferred_Email_data.value 
			$City = $City_data.value 
			$Dept = $Dept_data.value
			$Country = $Country_data.value
	}

}

#Populate UPN
if (-not $UPN) {$UPN = "$($FirstName[0])$($LastName)@$Domain"} #Defining UPN

#Log file
"Detected user $($FirstName) $($LastName) with display name $($DisplayName) at UPN $($UPN) and in city $($City) and Department $($Dept) with phone $($Phone)" | Out-File -Append -FilePath $logFile

#This string shows a screen which allows us to validate
#Use the UI
	try {
		$response = 1
		while ($response -ne 'Y') {
		write-host "Creating a user with the following values:"
		write-host "[1] First Name: $($FirstName)"
		write-host "[2] Last Name: $($LastName)"
		write-host "[3] A request was detected for email $($UPN_A) and will in fact create $($UPN)"
		write-host "[4] Job Title: $($TItle)"
		write-host "[5] City: $($City)"
		write-host "[6] Department: $($Dept)"
		if ($null -ne $Phone) {write-host "[7] Phone: $($Phone) (will be defined in AD)"} else {write-host "[8] Phone: None entered"}
		write-host "Full Name will be $($DisplayName)"
		write-host "--- Press 0 to add a user with these changes. Press 1 to edit First Name. Press 2 to edit Surname. Press 3 to edit UPN. Press 4 to edit Title. Press 5 to edit City. Press 6 to edit Department. Press 7 to edit phone. Press 8 to clear phone. Press 9 to abort. ---"
		$response = read-host -prompt "Enter your choice."
		switch ($response) {
		1 {$FirstName = read-host -prompt "Enter first name."} 
		2 {$LastName = read-host -prompt "Enter last name."}
		3 {$UPN = read-host -prompt "Enter the UPN."}
		4 {$Title = read-host -prompt "Enter user title."}
		5 {$City = read-host -prompt "Enter new city."}
		6 {$Dept = read-host -prompt "Enter department."}
		7 {$Phone = read-host -prompt "Enter user phone."}
		8 {$Phone = $null} #Here because phone number may have been incorrectly entered in Solarwinds.
		9 {exit}
		'Y' {$response = 1}
	 	}
		if ($response -eq 0) {$response = read-host -prompt "Are you sure? Y/N"}
	}
	}
	catch {
		Write-Warning "Invalid Entry. See error: $_"
	}

#Writes to AD
Write-Host "Attempting to connect to AzureAD...."
"Attempting to connect to AzureAD...." | Out-File -Append -FilePath $logFile
try {
	Connect-AzureAd
	if (-not $DisplayName) {$DisplayName = "$($FirstName) $($LastName)"}
	$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
	$PasswordProfile.Password = $Password

		#Defining the parameters for the command.
	$user_params = @{
	AccountEnabled = $true
	DisplayName = $DisplayName
	PasswordProfile = $PasswordProfile
	UserPrincipalName = $UPN
	Department = $Dept
	GivenName = $FirstName
	Surname = $LastName
	City = $City
	Country = $Country
	}
	if ($null -ne $Phone) {$user_params += @{TelephoneNumber = $Phone}}
	if ($null -ne $Title) {$user_params += @{JobTitle = $Title}}
	write-host "Creating a user with the following paramters:"
	write-host $user_params
	"Attempt to create the followng user has been initiated:" | Out-File -Append -FilePath $logFile
	$user_params | Out-File -Append -FilePath $logFile
	New-AzureADUser @user_params #Check to see if the at symbol needs to be a dollar sign instead.
	write-host "AD User successfully created!"
	"AD User successfully created!" | Out-File -Append -FilePath $logFile
}
catch {
	Write-Warning "$_"
	"User adding failed." | Out-File -Append -FilePath $logFile
}

#Giving the user licenses for Microsoft Business, Teams Phone, and Fabric
try {
        write-host "Connecting to Microsoft Graph.."
        Connect-MgGraph -Scopes User.ReadWrite.All, Organization.Read.All
        write-host "Connection successful.\nAttempting to grant the user a Business, Teams Phone, and Frabric License."
        "Connected to graph, attempting to grant the user a Business, Teams Phone, and Frabric License." | Out-File -Append -FilePath $logFile
        #Our licenses correspond to MCOEV,SPB, and FLOW_FREE respenctively. They can be found by running "Get-MgUserLicenseDetail -UserId "djoly@$Domain""
        $MCOEV = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq 'MCOEV'}
        $FLOW_FREE = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq 'FLOW_FREE'}
        $SPB = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq 'SPB'}
        $newLicenses = @(
        @{SkuId = $MCOEV.SkuId},
        @{SkuId = $FLOW_FREE.SkuId},
        @{SkuId = $SPB.SkuId}
        )
        Set-MgUserLicense -UserId $UPN -AddLicenses $newLicenses.SkuId -RemoveLicenses @() -WhatIf
        write-host "Licenses granted!"
        "Licenses successfully added." | Out-File -Append -FilePath $logFile

}
catch {
        Write-Warning "$_\nMoving on to the next step..."
        "Unable to assign a license. Moving on to the next step..." | Out-File -Append -FilePath $logFile
}

#Copy Teams
	try {
		$response = 1
		while ($response -ne "N") {
			if ($ReferenceUser -notlike "$Domain") {
				write-host "Reference user seems not to end in @$($Domain). Please change it before proceeding."
			}
			$response = read-host -Prompt "Copy Teams from reference user $($reference_user)? Press 1 to change the user. Y/N"
			if ($response -eq 'Y') {
				Connect-MicrosoftTeams
				get-team -user $ReferenceUser | Foreach-Object {Add-Team -GroupID $_.GroupID -User $UPN}
				write-host "Teams copied!"
				"Copied teams from $($ReferenceUser) to $($UPN)." | Out-File -Append -FilePath $logFile
				$response = "N"
			}
			if ($response -eq 1) {
				$ReferenceUser = read-host -Prompt "Enter the full email address of the reference user."
			}
		}
	}
	catch {
		write-warning "Error: $_"
	}

#Copy Mailboxes
	try {
		$response = 1
		while ($response -ne "N") {
			if ($ReferenceUser -notlike $Domain) {
				write-host "Reference user seems not to end in @$($Domain). Please change it before proceeding."
			}
			$response = read-host -Prompt "Copy Shared Mailboxes from reference user $($reference_user)? Press 1 to change the user. Y/N"
			if ($response -eq 'Y') {
				Connect-ExchangeOnline
				$mailbox_lists = (Get-Mailbox | get-MailboxPermission -User $ReferenceUser)
				ForEach-Object ($mailbox_lists) {Add-MailboxPermission -User $UPN -Identity "$_.Identity -AccessRights $_.AccessRights"}
				write-host "Mailboxes copied!"
				"Copied Mailboxes from $($ReferenceUser) to $($UPN)." | Out-File -Append -FilePath $logFile
				$response = "N"
			}
			if ($response -eq 1) {
				$ReferenceUser = read-host -Prompt "Enter the full email address of the reference user."
			}
        }
}
	catch {
		write-warning "Error: $_ "
	}

#Attempt to put a welcome email in your drafts folder.
Write-Host "Attempting to add two emails to your drafts folder..."
try {
    New-MailMessage -Subject " " -Body " " -WhatIf | Out-File -Append -FilePath $logFile
    New-MailMessage -Subject "Login Info for $($DisplayName)" -Body "An account for $($DisplayName) is now available. Their email is $($UPN), their phone number is $($Phone). Please give them this password: $($Password). Feel free to update the ticket with any further concerns."
    New-MailMessage -Subject "Welcome aboard, $($DisplayName)!" -Body "We at the IT department welcome your arrival. Your email is $($UPN) and your telephone number is $($Phone). You will have been given a password."
    write-host "A manager's email and a welcome email have been placed in your drafts folder! Please visit Outlook Online to view them." 
}
catch {
    Write-Warning "Error when attempting to add a new user:\n $_"
}

write-host "User creaction process has finished with password $($Password) "
"User creation complete" | Out-File -Append -FilePath $logFile
read-host