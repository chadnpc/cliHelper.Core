#!/usr/bin/env pwsh
function Initialize-CLISetup {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        
    }
    
    process {
        [string]$ascii = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('ICAgIOKVreKUgeKUgeKUgeKUs+KVriDila3ilIHilIHilIHila7ila3ila4gICAg4pWt4pWuDQogICAg4pSD4pWt4pSB4pWu4pSD4pSDIOKUg+KVreKUgeKVruKUo+KVr+KVsOKVriAgIOKUg+KUgw0KICAgIOKUg+KUgyDilbDilKvilIPila3ilKvilbDilIHilIHilYvila7ila3ilYvila4g4pWt4pSr4pSD4pWt4pSB4pSB4pWu4pSB4pWuDQogICAg4pSD4pSDIOKVreKUq+KUg+KUo+KVsOKUgeKUgeKVruKUg+KUg+KUg+KUg+KUgyDilIPilIPilIPilIPilIPilIHilKvila3ila8NCiAgICDilIPilbDilIHila/ilIPilbDilKvilIPilbDilIHila/ilIPilIPilbDilKvilbDilIHila/ilIPilbDilKvilIPilIHilKvilIMNCiAgICDilbDilIHilIHilIHilLvilIHilLvilLvilIHilIHilIHila/ilbDilIHilLvilIHila7ila3ila/ilIHilLvilIHilIHilLvila8NCiAgICDwnZWU8J2VoPCdlZXwnZWWIPCdlajwnZWa8J2VpfCdlZkg8J2VpPCdlaXwnZWq8J2VnfCdlZbila3ilIHila8NCiAgICAgICAgICAgICAgICAgICDilbDilIHila8NCg0K'));
        Write-Host $ascii -ForegroundColor Green
    }
    
    end {
        
    }
}