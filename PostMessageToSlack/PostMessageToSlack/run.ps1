
<#
.SYNOPSIS
Post message to Slack

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

.EXAMPLE
Run.ps1 -Request Request -TriggerMetadata TriggerMetadata

#>

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$yourUri = "https://hooks.slack.com/services/"

$hook = $env:SLACKTOKEN


$name = $Request.Query.Username
if (-not $name) {
    #Write-Host $Request.Body
    $name = $Request.Body.username
    #$resourceName = $Request.Body.data.context.resourceName
    #Write-Host $resourceName
    #$timestamp = $Request.Body.data.context.timestamp
}

$mkdwn = $true

if ($name) {
    Write-Host "Username supplied is ${name}" 
    $status = [HttpStatusCode]::OK
    $rawcreds = @{
        mkdwn = $mkdwn
        text = $name
        attachments = @(@{
            color= "good"
            text = $Request.Body.text 
        })
    }
    $json = $rawcreds | ConvertTo-Json
    $body = $json
    Invoke-WebRequest -Uri "${yourUri}${hook}" -Method Post -Body $body
    Write-Host "Message sent out by Web-Request with username ${name} and body ${body}"
} else {
    $status = [HttpStatusCode]::BadRequest
    $body = "Please pass a name on the query string or in the request body."
    Write-Host "${body}"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})

