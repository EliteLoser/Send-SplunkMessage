# Send-SplunkMessage
Send-STSplunkMessage is a PowerShell version 2-compatible function for sending ad hoc splunk messages to specified index, source, source type and (list of) Splunk forwarder URI(s). The function converts an -InputObject to JSON using either ConvertTo-STJson on PSv2 and if -CoerceNumberStrings is specified or the built-in ConvertTo-Json on PSv3+

![test](/Images/20210601 splunktest.jpg)

