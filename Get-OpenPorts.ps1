<#
This is an alternative way to the Test-Connection cmdlet.  I have a static list I was using for testing, but can be chaned to read in a txt file.  The "foreach" block cleans up the origianl "ping" results to only display IP's that respond to the 1st icmp packet and stores them in a variable that can be used later.  The catch block only displays the IP's that did not respond to the 1st ICMP packet.  It can be coded to send those results to a file or variable for further analysis

#>

# $IPList = read-host "Please enter the file path of the host list"

$IPList = 1..255 | ForEach-Object {"10.10.10.$_"}

$ReplyResults = @()
foreach ($node in ($IPList)){
    $icmpresults = ping $node -n 1 
    try {
        $ReplyResults += ((($icmpresults | Select-String "reply" | Where-Object {$_ -notlike "*unreachable*"}).ToString()).Split(" ")[2]).TrimEnd(":")
    }
    catch {
        write-host "$node is not accessable"
    }

    
} 
$ReplyResults #| out-file .\OnlineIPs.txt

#############################################
# Adding a port scanner on here now
##############################################

<#
This information was based off of the work of Jeff Hicks

https://petri.com/building-a-powershell-ping-sweep-tool-adding-a-port-check
https://docs.microsoft.com/en-us/dotnet/api/system.net.sockets.socket?view=net-6.0
https://docs.microsoft.com/en-us/dotnet/api/system.net.sockets.tcpclient?view=net-6.0
#>

# Create the TCP Socket variable using .Net ( Assuming I can do this with UDP as well)
$IPS = "10.4.1.180", "127.0.0.1"
$TCPports = 443,1434,139,22,8080

$OpenPortList  = @()

foreach ($IP in $IPS){
    foreach ($port in $TCPports){
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcpConnection = $tcp.ConnectAsync($IP,$Port)
        $wait = $tcpConnection.AsyncWaitHandle.WaitOne(1000, $false)
        if (!$wait){
            Write-host "$port is closed on $IP Machine"
            $OpenPort = [PSCustomObject]@{
                Port = $port
                Host = $IP
                Status = "Closed"
            }
            $OpenPortList += $OpenPort
        } # Close If Statemen
        else {
            Write-host "$port is Open on $IP Machine"
            $OpenPort = [PSCustomObject]@{
                Port = $port
                Host = $IP
                Status = "Open"
            }
            
        }# Close Else Statement
    $tcp.Dispose()

    } #close Port foreach loop
} #close IP foreach loop

$OpenPortList

#$wait = $tcpConnection.AsyncWaitHandle.WaitOne(1000, $false)

$IP = "10.4.1.180"
$Port = 443

$OpenPortList = @()

$tcp = New-Object System.Net.Sockets.TcpClient
$tcpconnection = $tcp.ConnectAsync($IP,$port) 
$wait = $tcpConnection.AsyncWaitHandle.WaitOne(1000, $false)
 
if (!$wait){
    Write-host "$port is closed on $IP Machine"
}
else {
    Write-host "$port is Open on $IP Machine"
    $OpenPort = [PSCustomObject]@{
        Port = $port
        Host = $IP
    }

    $OpenPortList += $OpenPort
    $tcpConnection.Dispose()  
} 

$tcp.Dispose()

##############################################################
# UDP Configuration Here
##############################################################

# [int]$UDPports = 53, 88