<#
    .SYNOPSIS 
        Givin an IP and a list of ports, this script will check to see if those ports are open on the each IP.
    .DESCRIPTION
        The Script loops through a list of IPs.  In that loop, it stars looping through the list of Ports.  During that loop it checks to see if that port is open.  It start loop with the TCP ports.  When finished, it starts looping though the UDP ports.  All results are stored in a variable called "OpenPortList" and exports a CSV file to your current directory.  The variable OpenPortList is an object so you can sort, filter or group on its various properties.
    .PARAMETER IP
        
    .PARAMETER TCP
        
    .PARAMETER UDP
                
    .EXAMPLE
               
    .NOTES
      
    #>

#############################################################################################
# Start Ping Sweep
#############################################################################################

$IPList = 1..255 | ForEach-Object {"10.4.1.$_"}

$ReplyResults = @()
$i = 0
foreach ($node in ($IPList)){
    $i += 1
    Write-Progress “Scanning Network” -PercentComplete (($i/$IPList.Count)*100)
    $icmpresults = ping $node -n 1 
    try {
        $ReplyResults += ((($icmpresults | Select-String "reply" | Where-Object {$_ -notlike "*unreachable*"}).ToString()).Split(" ")[2]).TrimEnd(":")
    }
    catch {
        write-host "$node is not accessable"
    }
} 
$ReplyResults | out-file .\OnlineIPs.txt

#############################################
# Adding a TCP port scanner on here now
##############################################

<#
.NOTES
This information was based off of the work of Jeff Hicks

https://petri.com/building-a-powershell-ping-sweep-tool-adding-a-port-check
https://docs.microsoft.com/en-us/dotnet/api/system.net.sockets.socket?view=net-6.0
https://docs.microsoft.com/en-us/dotnet/api/system.net.sockets.tcpclient?view=net-6.0
#>

$TCPports = 443,1434,139,22,8080
$UDPports = 53,88,137,138,3702,4500,5050,5353,5355,22

$OpenPortList  = @()
$it1 = 0
$it2 = 0
foreach ($IP in $ReplyResults){
    $it1 += 1
    #Write-Progress “Scaning Targets” -PercentComplete (($it1/$ReplyResults.Count)*100)
    foreach ($port in $TCPports){
        $it2 += 1
        #Write-Progress “Scanning Ports” -PercentComplete (($it2/$TCPports.Count)*100)
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcpConnection = $tcp.ConnectAsync($IP,$Port)
        $wait = $tcpConnection.AsyncWaitHandle.WaitOne(1000, $false)
        if (!$wait){
            Write-host "TCP $port is closed on $IP Machine"
            $OpenPort = [PSCustomObject]@{
                Proto = "TCP"
                Port = $port
                Host = $IP
                Status = "Closed"
            }
            $OpenPortList += $OpenPort
        } # Close If Statemen
        else {
            Write-host "TCP $port is Open on $IP Machine"
            $OpenPort = [PSCustomObject]@{
                Proto = "TCP"
                Port = $port
                Host = $IP
                Status = "Open"
            }
            $OpenPortList += $OpenPort
        }# Close Else Statement
    $tcp.Dispose()

    } #close Port foreach loop

############################################################
# Start my UDP Loop Here
############################################################

<#
.NOTES
This information is based off of work that I found at the following sites

https://docs.microsoft.com/en-us/dotnet/api/system.net.ipendpoint.-ctor?view=net-6.0
https://gist.github.com/pagliacci/00f438e7371f7116cc57
https://docs.microsoft.com/en-us/dotnet/api/system.net.sockets.udpclient.receive?view=net-6.0#system-net-sockets-udpclient-receive(system-net-ipendpoint@)

#>
    foreach ($port in $UDPports){
        $udpObject = New-Object System.Net.Sockets.UdpClient
        $udpObject.Client.ReceiveTimeout = 1000
        $udpObject.Connect($IP, $port)
        $ASCIItext = New-Object System.Text.ASCIIEncoding
        $byte = $ASCIItext.GetBytes("My Payload")
        [void]$udpObject.Send($byte, $byte.Length)

        $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any, 0)

        try {
            $receivebytes = $udpobject.Receive([ref]$remoteendpoint)
            [string]$returndata = $ASCIItext.GetString($receivebytes)
            
            if ($returndata) {
                Write-host "UDP $port is Open on $IP Machine"
                $OpenPort = [PSCustomObject]@{
                    Proto = "UDP"
                    Port = $port
                    Host = $IP
                    Status = "Open"
                }
                $OpenPortList += $OpenPort
                $udpObject.Close()
            }
        } # Close try
        Catch {
            If ($Error[0].ToString() -match "failed to respond") {
                if ((Get-CimInstance Win32_PingStatus -Filter "(address='$IP' and timeout=10000)").StatusCode -eq 0){
                    Write-host "UDP $port is Open on $IP Machine"
                $OpenPort = [PSCustomObject]@{
                    Proto = "UDP"
                    Port = $port
                    Host = $IP
                    Status = "Filtered"
                }
                $OpenPortList += $OpenPort
                } # Close PingStatus IF block
            } elseif ($Error[0].ToString() -match "forcibly closed") {
                Write-host "UDP $port is Closed on $IP Machine"
                $OpenPort = [PSCustomObject]@{
                    Proto = "UDP"
                    Port = $port
                    Host = $IP
                    Status = "Closed"
                }
                $OpenPortList += $OpenPort
            }# Close Error If block
        } #Close Catch Block
    $udpObject.Close()
    } # Close Ports Foreach Block

} #close IP foreach loop

$OpenPortList | eport-csv .\OpenPortList.csv

