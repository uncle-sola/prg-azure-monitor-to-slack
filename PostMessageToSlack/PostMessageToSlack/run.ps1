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

