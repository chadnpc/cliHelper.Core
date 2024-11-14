function Test-EmailAddress {
    <#
.SYNOPSIS
    Tests validity if specified string is an email address.
.DESCRIPTION
    Casts the passed value as "System.Net.Mail.MailAddress" data type.
    If successful it parses string into the properties: DisplayName, User, Host, Address
    White space normally delimits the DisplayName from the address so an extra check
    is performed to see if EmailAddress specified matches the resolved Address property
.EXAMPLE
    Test-EmailAddress -EmailAddress "user@gmail.com"

    Would return:
    True
.EXAMPLE
    Test-EmailAddress "bademail"

    Would return:
    False
.EXAMPLE
    Test-EmailAddress "test user@gmail.com" -verbose

    Would return:
    VERBOSE: You entered email address: [test user@gmail.com]
    VERBOSE: Address resolved to: [user@gmail.com]
    VERBOSE: [user@gmail.com] does not match [test user@gmail.com]
    VERBOSE: The address is NOT valid.
    False
.EXAMPLE
    Test-EmailAddress -EmailAddress "user@gmail.com" -verbose

    Would return:
    VERBOSE: You entered email address: [user@gmail.com]
    VERBOSE: Address resolved to: [user@gmail.com]
    VERBOSE: Address valid, no guarantee that address [user@gmail.com] exists.
#>

    [CmdletBinding(ConfirmImpact = 'None')]
    [Outputtype('bool')]
    Param (
        [parameter(Mandatory, HelpMessage = 'Add help message for user', Position = 0, ValueFromPipeLine, ValueFromPipeLineByPropertyName)]
        [Alias('Address')]
        [string] $EmailAddress
    )

    begin {
        Write-Invocation $MyInvocation
    }

    process {
        Out-Verbose "You entered email address: [$($EmailAddress)]"
        try {
            $temp = [System.Net.Mail.MailAddress] $EmailAddress
            Out-Verbose "Address resolved to: [$($temp.Address)]"
            if ($temp.Address -ne $EmailAddress) {
                Out-Verbose "[$($temp.Address)] does not match [$($EmailAddress)]"
                Write-Output -InputObject $false
            } else {
                Out-Verbose "Address valid, no guarantee that address [$($EmailAddress)] exists."
                Write-Output -InputObject $True
            }
        } catch {
            Out-Verbose  'The address is NOT valid.'
            Write-Output -InputObject $False
        }
    }

    end {
        Out-Verbose $fxn "Complete."
    }
}
