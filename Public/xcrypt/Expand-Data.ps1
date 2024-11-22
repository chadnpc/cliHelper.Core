function Expand-Data {
  [CmdletBinding(DefaultParameterSetName = 'bytes')]
  [OutputType([byte[]], [string])]
  param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'bytes')]
    [alias('b')][byte[]]$Bytes,

    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'str')]
    [Alias("t", "str")][String]$Plaintext,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = '__AllParameters')]
    [Alias('c')][Compression]$Compression = 'Gzip'
  )

  process {
    $res = $null
    if ($PSCmdlet.ParameterSetName -eq 'bytes') {
      $res = Expand-Data -b $bytes -c $Compression
    } else {
      $res = Expand-Data -t $Plaintext -c $Compression
    }
  }

  end {
    return $res
  }
}
