<#
.SYNOPSIS
Posts an Azure Monitor alert from an action group webhook to Slack

.DESCRIPTION
This azure function takes a HTTP post request,  and posts a message into Slack. 

It requires:

* A POST request be made to /api/MonitorAlert.

* The request must have a "channel" parameter on the query string, and will return a Bad Request status code if it does not.  
This value is the channel (minus the #) that the message will be posted to.

* The environment must have a "SlackToken" variable, containing the slack token to use to post to slack with.  
The request will return a HTTP bad status if it does not exist.

*  The request body must contain the json for the alert.  

A schema for the payload can be found at the following link:

https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-metric-near-real-time#payload-schema

Some possible improvements:
    * Update to add support for the common alert schema

.PARAMETER Request

The request object. This is populated via the Azure Function runtime.

.PARAMETER TriggerMetadata

Meta-data about the functions invocation. Populated by the Azure Function runtime.

#>

using namespace System.Net

param($Request, $TriggerMetadata)

Import-Module PayStackAlertHelperModule

Write-Host "PowerShell HTTP trigger function processed a request."

$channel = $Request.Query.Channel
$slackToken = $env:SLACKTOKENPAYSTACK


# String key = "YOUR_SECRET_KEY"; //replace with your paystack secret_key
#       String jsonInput = "{"paystack":"request","body":"to_string"}"; //the json input
#       String inputString = Convert.ToString(new JValue(jsonInput));
#       String result = "";
#       byte[] secretkeyBytes = Encoding.UTF8.GetBytes(key);
#       byte[] inputBytes = Encoding.UTF8.GetBytes(inputString);
#       using (var hmac = new HMACSHA512(secretkeyBytes))
#       {
#           byte[] hashValue = hmac.ComputeHash(inputBytes);
#           result = BitConverter.ToString(hashValue).Replace("-", string.Empty);;
#       }
#       Console.WriteLine(result);
#       String xpaystackSignature = ""; //put in the request's header value for x-paystack-signature
  
#       if(result.ToLower().Equals(xpaystackSignature)) {
#           // you can trust the event, it came from paystack
#           // respond with the http 200 response immediately before attempting to process the response
#           //retrieve the request body, and deliver value to the customer
#       } else {
#           // this isn't from Paystack, ignore it
#       }

if ([string]::IsNullOrWhiteSpace($channel)) {
    Push-OutputBindingWrapper -Status BadRequest -Body "channel not specified in query"   
    return
}

if ([string]::IsNullOrWhiteSpace($slackToken)) {
    Push-OutputBindingWrapper -Status BadRequest -Body "Slack token not specified"   
    return 
}

$secret = $env:PAYSTACKSECRET
if ([string]::IsNullOrWhiteSpace($secret)) {
    Push-OutputBindingWrapper -Status BadRequest -Body "PayStack secret not specified"   
    return 
}

$storageAccountkey = $env:STORAGEACCOUNTKEY
if ([string]::IsNullOrWhiteSpace($storageAccountkey)) {
    Push-OutputBindingWrapper -Status BadRequest -Body "StorageAccountKey key not specified"   
    return 
}

if($null -eq $request.Body) { 
    Push-OutputBindingWrapper -Status BadRequest -Body "Unable to parse body as json"
    return
}

if($null -eq $request.Body.data) { 
    Push-OutputBindingWrapper -Status BadRequest -Body "Unable to parse data as json"
    return
}

if($null -eq $request.Body.event) { 
    Push-OutputBindingWrapper -Status BadRequest -Body "Unable to parse event as json"
    return
}


$body = $request.Body | ConvertTo-Json -Depth 4
Write-Information "body $($body)" -Verbose

$jsonRequest = @{    
    paystack = "request"
    body = "$body"
}

Write-Information "jsonRequest $($jsonRequest)" -Verbose

$jsonObject = $jsonRequest | ConvertTo-Json

Write-Information "jsonObject  $($jsonObject)" -Verbose

$jsonString = $jsonObject




$hmacsha = New-Object System.Security.Cryptography.HMACSHA512
$hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
$signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($jsonString))
$signature = [System.BitConverter]::ToString($signature);
$signature = $signature.Replace("-","")
$signature = $signature.ToLower()
Write-Information "Computed signature $($signature)" -Verbose
$suppliedSignature = $Request.Headers["x-paystack-signature"]
Write-Information "Supplied signature $($suppliedSignature)" -Verbose


# Do we get the expected signature?
if ($signature -ne $suppliedSignature) {
    # Push-OutputBindingWrapper -Status BadRequest -Body "Failed Signature test"
    Write-Information "Failed Signature test"
    #return
}



# $tableStorageCurr = Get-Content $inputTable -Raw | ConvertFrom-Json

# $currStorageItem = $tableStorageCurr | where-object RowKey -eq $Request.Body.Data.id

# if ($null -ne $currStorageItem) {
#     Write-Information "Dont send message"
#     Push-OutputBindingWrapper -Status OK -Body "success"
#     return
# }

# $tableStorageItems = @()

# $tableStorageItems += [PSObject]@{
# PartitionKey = $Request.Body.event
# RowKey = $Request.Body.Data.id
# payStackId = $Request.Body.Data.id
# }

# $tableStorageItems | ConvertTo-Json | Out-File -Encoding UTF8 $outputTable

# Write-Information "Added new record"
# #Add-AzTableRow -table $cloudTable -partitionKey $($Alert.event) -rowKey $($Alert.Data.id) -property @{"payStackId"=$($Alert.Data.id)} 

$SendSlack = Test-ShouldSendSlackMessage -Alert $Request.Body -storageAccountKey $storageAccountkey
#$SendSlack = [System.Convert]::ToString($objSendSlack)
Write-Information "back to run.ps1 $SendSlack"
if ($SendSlack -eq "no") {

    Write-Information "Dont send message"
    Push-OutputBindingWrapper -Status OK -Body "success"
    return

} else {

    Write-Information "Send message"
    $message = New-SlackMessageFromAlert -Alert $Request.Body -Channel $channel

    try {    
        Send-MessageToSlack -SlackToken $slackToken -Message $message
    }
    catch {
        Push-OutputBindingWrapper -Status BadRequest -Body ("Unable to send slack message:", $_.Exception.Message)
        return     
    }

    Push-OutputBindingWrapper -Status OK -Body "success"
}

