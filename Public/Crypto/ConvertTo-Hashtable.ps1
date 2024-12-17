function ConvertTo-Hashtable {

  [cmdletbinding()]
  [OutputType([System.Collections.Specialized.OrderedDictionary])]
  [OutputType([System.Collections.Hashtable])]

  Param(
    [Parameter(
      Position = 0,
      Mandatory,
      HelpMessage = "Please specify an object",
      ValueFromPipeline
    )]
    [ValidateNotNullorEmpty()]
    [object]$InputObject,
    [switch]$NoEmpty,
    [string[]]$Exclude,
    [switch]$Alphabetical,
    [Parameter(HelpMessage = "Create an ordered hashtable instead of a plain hashtable.")]
    [switch]$Ordered
  )

  Process {
    <#
            get type using the [Type] class because deserialized objects won't have
            a GetType() method which is what I would normally use.
        #>

    $TypeName = [system.type]::GetTypeArray($InputObject).name
    Write-Verbose "Converting an object of type $TypeName"

    #get property names using Get-Member
    $names = $InputObject | Get-Member -MemberType properties |
      Select-Object -ExpandProperty name

    if ($Alphabetical) {
      Write-Verbose "Sort property names alphabetically"
      $names = $names | Sort-Object
    }

    #define an empty hash table
    if ($Ordered) {
      Write-Verbose "Creating an ordered hashtable"
      $hash = [ordered]@{ }
    } else {
      $hash = @{ }
    }

    #go through the list of names and add each property and value to the hash table
    $names | ForEach-Object {
      #only add properties that haven't been excluded
      if ($Exclude -notcontains $_) {
        #only add if -NoEmpty is not called and property has a value
        if ($NoEmpty -AND !($inputobject.$_)) {
          Write-Verbose "Skipping $_ as empty"
        } else {
          Write-Verbose "Adding property $_"
          $hash.Add($_, $inputobject.$_)
        }
      } else {
        Write-Verbose "Excluding $_"
      }
    }
    Write-Verbose "Writing the result to the pipeline"
    Write-Output $hash
  }
}
