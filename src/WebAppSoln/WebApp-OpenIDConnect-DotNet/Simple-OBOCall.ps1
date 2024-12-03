param (
    [Parameter()]
    [string] $storageAccountName = "stwebappjqlzyrm7hw4ou",
    [Parameter()]
    [string] $containerName = "somecontainer",
    [Parameter(Mandatory = $false)]
    [string] $oboToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6Inp4ZWcyV09OcFRrd041R21lWWN1VGR0QzZKMCIsImtpZCI6Inp4ZWcyV09OcFRrd041R21lWWN1VGR0QzZKMCJ9.eyJhdWQiOiJodHRwczovL3N0b3JhZ2UuYXp1cmUuY29tIiwiaXNzIjoiaHR0cHM6Ly9zdHMud2luZG93cy5uZXQvYWE5M2I5ZDktMDM3ZC00ZjA4LWEyNmQtNzgzY2ZmMGUyMzY5LyIsImlhdCI6MTczMzIwNzQzMiwibmJmIjoxNzMzMjA3NDMyLCJleHAiOjE3MzMyMTE5OTUsImFjciI6IjEiLCJhaW8iOiJBWVFBZS84WUFBQUFVWXBMMDB0VDFjb2Rzb3NZQjl3Y0dKcnZRSDJnWGVqdG1ubU1Ka2ZGZERNUEptekJCTzdMN2RWMDYwMElydmhkcHVGSk52aUZCbDZ4c1RqMnZXdENqNVpxOFpoUW5DMU03aHRFRjRHYTRUUmliQWRGOWhidGZZWTZQSXBHcVVTNGtGRGZEVVlacXhhbHRqdC9JTi94Y3pUMy9Ja0daUEpQMktTWE9iaXVtQUU9IiwiYW1yIjpbInB3ZCIsInJzYSIsIm1mYSJdLCJhcHBpZCI6ImI3Mjk0OWQxLWIxZjQtNDFjYy1hMzcwLTVmYTVmNGU0MGQxMCIsImFwcGlkYWNyIjoiMSIsImRldmljZWlkIjoiMjgzMGQ3ZDktM2QwZS00OWYzLTg1MjUtNDQzY2Y1NjYzZGY1IiwiZmFtaWx5X25hbWUiOiJBZG1pbmlzdHJhdG9yIiwiZ2l2ZW5fbmFtZSI6IlN5c3RlbSIsImdyb3VwcyI6WyIzMDY4ZTI4Mi01YzlhLTRkZTktODYyZS0wNzZiYzBjNTliYmYiLCIzNjhiMzVhNy05NDBkLTQwOWUtOTZiNS00NWFiMzhhMGVhNjUiLCI4NWMwNTZhYy1kNTljLTQ2NmMtYjg4MC02NDE0NWRiNzQzZjQiLCIxYTAxZTE2MC1lZjA0LTQyZTctYjBkZS1kMmRlZGFjYWIzMTciLCJkNDRhMDI3NS1lN2VmLTRjM2EtYTE4MC0xZThiZGVjYzU5NTYiXSwiaWR0eXAiOiJ1c2VyIiwiaXBhZGRyIjoiNzYuNjUuNjAuMTQ3IiwibmFtZSI6IlN5c3RlbSBBZG1pbmlzdHJhdG9yIiwib2lkIjoiYjc4NTIzMGEtNGFmNC00MThhLWFjZDktYWVhOTk4OTRkMzdhIiwicHVpZCI6IjEwMDMyMDAzQUZBNkU4NUYiLCJyaCI6IjEuQWJjQTJibVRxbjBEQ0UtaWJYZzhfdzRqYVlHbUJ1VFU4NmhDa0xiQ3NDbEpldkg4QU1pM0FBLiIsInNjcCI6InVzZXJfaW1wZXJzb25hdGlvbiIsInN1YiI6IkZLOVVIT2tlWVRLSXZqUGJCOWRvX0xCSWJHREhILTdPZ1BvQ0Y0cTF4STAiLCJ0aWQiOiJhYTkzYjlkOS0wMzdkLTRmMDgtYTI2ZC03ODNjZmYwZTIzNjkiLCJ1bmlxdWVfbmFtZSI6ImFkbWluQE1uZ0Vudk1DQVA2NzU2NDYub25taWNyb3NvZnQuY29tIiwidXBuIjoiYWRtaW5ATW5nRW52TUNBUDY3NTY0Ni5vbm1pY3Jvc29mdC5jb20iLCJ1dGkiOiJwaWQya3ZCVWVrTzdtSHUxUDYwNkFRIiwidmVyIjoiMS4wIiwieG1zX2lkcmVsIjoiMTggMSJ9.EwjgWv5OzHAE7I3vwCmagy2rTO37EJ06jdyQxmFD7AiHaf_WxhRNPhml67FlpJeNiZqGUJMPN49x_3wdITufnxw_hZZWDhwTEBVjw2bLxy_3_NOu_GJMn8P6hMu1YvHEIBZZLw8X3waLICwosvIa4FG2OIaRUaBJdjGuxV4S4HvwFRaWvB2MFW7_T7lvHOKfieUkmtgrgDLp2uM4vYvOVCrcKAJyTxiEMy9ib4NORXBenvDlAVw-0H2WNWGujzNhG-hp_IHOovubrgECziI9L5O0v6q46xR_dRURbzP2VXTYEri4XKIFU2M4DK6EJtM2RsHynp26C6uoCKXs8sPOrA"
)

# Define the storage account name and the container name

Write-Output "Storage account name: $storageAccountName"
Write-Output "Container name: $containerName"
Write-Output "OBO token length: $($oboToken.Length)"


# Define the URI for the storage account
$uri = "https://$storageAccountName.blob.core.windows.net/${containerName}?restype=container&comp=list"

Write-Output "URI: $uri"

# Obtain the OBO token (this example assumes you already have the token)
#$oboToken = "your_obo_token"

Write-Output "Creating the authorization header"

# Create the authorization header
# get utc date
$authHeader = @{
    'Authorization' = "Bearer $oboToken"
    'x-ms-version'  = "2020-10-02"
    'Accept'        = "application/json"
    #'x-ms-date'     = (Get-Date).ToUniversalTime().ToString('R')
}

# Write the authorization header as JSON
$authHeader | ConvertTo-Json

Write-Output "Making the GET request"

# Make the GET request
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader

Write-Output "Response received"

# Output the response
$response

# Write the response to a file -- formatting nicely the xml response
$response | Out-File -FilePath "response.xml"
