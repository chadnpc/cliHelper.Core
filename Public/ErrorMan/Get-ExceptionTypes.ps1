function Get-ExceptionTypes {
  [CmdletBinding()][OutputType([ExceptionType[]])]
  param ()

  process {
    return [ErrorManager]::get_ExceptionTypes()
  }
}