<#$wait = $tcpConnection.AsyncWaitHandle.WaitOne(1000, $false)

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
#>
##############################################################
# UDP Configuration Here
# https://learn-powershell.net/2011/02/21/querying-udp-ports-with-powershell/
##############################################################

$UDPports = 53,88,137,138#,3702,5353

foreach ($port in $UDPports){
    $udpObject = New-Object System.Net.Sockets.UdpClient
    $udpObject.Client.ReceiveTimeout = 1000
    $udpObject.Connect("10.4.1.180", $port)
    $ASCIItext = New-Object System.Text.ASCIIEncoding
    $byte = $ASCIItext.GetBytes("My Payload")
    [void]$udpObject.Send($byte, $byte.Length)

    $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any, 0)

    try {
        $receivebytes = $udpobject.Receive([ref]$remoteendpoint)
        [string]$returndata = $ASCIItext.GetString($receivebytes)
        
        if ($returndata) {
            write-host "$port UDP port is open"
            $udpObject.Close()
        }
    } # Close try
    Catch {
        If ($Error[0].ToString() -match "failed to respond") {
            if ((Get-CimInstance Win32_PingStatus -Filter "(address='10.4.1.180' and timeout=10000)").StatusCode -eq 0){
                write-host "$port UDP port is open"
            } # Close PingStatus IF block
        } elseif ($Error[0].ToString() -match "forcibly closed") {
            write-host "$port UDP port is closed"
        }# Close Error If block
    } #Close Catch Block
$udpObject.Close()
} # Close Ports Foreach Block

