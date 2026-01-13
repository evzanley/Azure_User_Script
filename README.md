# NewAzureUser
Powershell script to create a new user for Entra AD in Azure.

Prerequisites: PowerShell version 5.1 with the AzureAD Module.

To check your version of PowerBI, run:

```$PSVersionTable```

To install AzureAD, run:

```Install-Module -Name AzureAD```

You can then create a new user in your Azure AD environment by running:

```
.\AddUser.ps1 -FirstName Fore -LastName Last -Password password -Dept Fake -City Exampletown -Phone 3333333333 -Title JobTitle -ReferenceUser olduser@domain.com -Domain domain.com
