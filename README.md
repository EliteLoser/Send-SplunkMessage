# Send-STSplunkMessage
Send-STSplunkMessage is a PowerShell version 2-compatible function for sending ad hoc splunk messages to specified index, source, source type and (list of) Splunk forwarder URI(s). The function converts an -InputObject to JSON using either ConvertTo-STJson on PSv2 and if -CoerceNumberStrings is specified - or the built-in ConvertTo-Json on PSv3+

ConvertTo-STJson can be found here: https://github.com/EliteLoser/ConvertTo-Json/blob/master/ConvertTo-STJson.ps1 ( https://github.com/EliteLoser/ConvertTo-Json/ ).

This isn't perfected in every detail, but pretty decent. Eagerly awaiting feedback and pull requests and/or suggestions. Open an issue if you have a suggestion
or question.

Typically Splunk gets messages on Windows from the event log, but if you find a need to easily send Splunk some data, this is very well suited for the task.

A lot of the design decisions are question marks in my head as to whether they're done well (enough). Such as the output being a string on success and
otherwise issuing warnings combined with some verbose output. Feedback is valued, really. I want this to be usable, functional and a "go to" piece of
code for "everyone" who has this need. Collaboration to achieve this goal would be great.

Any (or most) input is valued as issues. :)

Below is a screenshot of a successful "splunking" of a message that also demonstrates most of the parameters. I put in a kind of odd "place to hardcode"
URIs to splunk forwarders in the code, but this is ignored if you don't do it, and you get a sane message telling you it's required. This script I ran on my
computer had hard-coded Splunk URIs which is why I don't have to list one. I think this is what many would end up doing either in a wrapper/calling script
or in the parameter definition in the script, so I just put in a place for it. Use as needed/desired.

If a forwarder is bad, it gets "popped" out of the list (if more than one is specified), and will not be retried. If a once good forwarder goes bad, this
is also handled. There is no "once good forwarder" cache, so you can "run out of forwarders", but usually, of course, only one accessible forwarder is required,
and obviously the point is to use valid forwarders. But for robustness' sake I made it try them all before giving up. If one that works is found, it will be reused
until it goes bad (if it does). Quite a bit of logic to handle that, but not so clunky.

That's what I can think of to mention right now.

Here's the image (the function name is lacking "ST", sorry about that, it's Send-STSplunkMessage in the code here):

![splunked_message_demo](/Images/20210601splunktest.jpg)

