function Get-ItemSize {
  <#
    .SYNOPSIS
        Gets file size into a human readable format (B, KB, MB, GB ...)
    .DESCRIPTION
        Returns to console host, Formatted sizebytes that are more human readable.
    .INPUTS
        None
    .OUTPUTS
        Returns a string representation of the file size in a more friendly
        format based on the passed in bytes.
    .PARAMETER Size
        The size of a file in bytes.
    .PARAMETER IgnoredArguments
        Allows splatting with arguments that do not apply. Do not use directly.
    .EXAMPLE
        gci -File -Recurse -Depth 2 | Sort-Object Length -Descending | Select-Object name, @{l='Size'; e={Get-ItemSize $_.fullName}}
    .LINK
        https://github.com/chadnpc/devHelper/blob/main/Private/devHelper.Cli/Public/Get-ItemSize.ps1
    #>
  [CmdletBinding()]
  [OutputType([PSObject])]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [string]$Path,
    [parameter(ValueFromRemainingArguments = $true)]
    [Object[]]$ignoredArguments
  )

  Begin {
    function Format-SizeBytes {
      param (
        [Parameter(Mandatory = $true, Position = 0)]
        [double]$size
      )
      end {
        # Do not log function call, it interrupts the single line download progress output.
        foreach ($unit in @('B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB')) {
          if ($size -lt 1024) {
            return [string]::Format("{0:0.##} {1}", $size, $unit).Trim();
          }
          $size /= 1024
        }
        return [string]::Format("{0:0.##} YB", $size).Trim();
      }
    }
  }
  process {
    [double]$size = if (Test-Path $Path -PathType Container -ErrorAction SilentlyContinue) {
      Write-Verbose "Calculating Folder size for $Path ..."
      Get-ChildItem -Path $Path -File -Recurse -Force | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty sum
      # Todo: Add a folder size Calculator class with a cool progress Bar
    } else {
      Get-Item -Path $Path | Select-Object -ExpandProperty Length
    }
  }

  end {
    return [PSCustomObject]@{
      bytes = $size
      size  = Format-SizeBytes $size
      Item  = Get-Item $Path
    }
  }
}
