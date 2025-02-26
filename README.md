<h2>
<img align="right" src="https://github.com/user-attachments/assets/594f7b37-92f6-4ca3-9172-8c2a5a183aff" width="190" height="190" alt="icon" />
</h2>
<div align="Left">
  <a href="https://www.powershellgallery.com/packages/cliHelper.core"><b>cliHelper.core</b></a>
  <p>
    A collections of essential PowerShell functions that stonks up your terminal game
    </br></br></br>
    <a href="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_windows.yaml">
    <img src="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_windows.yaml/badge.svg" alt="Build on Windows"/>
    </a>
    <a href="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_Mac.yaml">
    <img src="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_Mac.yaml/badge.svg" alt="Build on MacOS"/>
    </a>
    <a href="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_Linux.yaml">
    <img src="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_Linux.yaml/badge.svg" alt="Build on Linux"/>
    </a>
    <a href="https://www.powershellgallery.com/packages/cliHelper.core">
    <img src="https://img.shields.io/powershellgallery/dt/cliHelper.core.svg?style=flat&logo=powershell&color=blue" alt="PowerShell Gallery" title="PowerShell Gallery" />
    </a>
  </p>
</div>

<h2><b>Usage</b></h2>

```PowerShell
Install-Module cliHelper.core
```

then

```PowerShell
Import-Module cliHelper.core

$art = Create-CliArt "https://pastebin.com/raw/p29UR385" -Taglines "Build. Ship. Repeat."; $art.Replace("x.y.z", "0.2.4");
$art.Write(15, $false, $true)
```

<!--
https://github.com/user-attachments/assets/2a8c8688-2483-4a44-8801-37fde5016306
-->

## license

This project is licensed under the [WTFPL License](LICENSE).

## thank you!

<p>
👍 ✨ Special thanks goes to:</br>
- <a href="https://github.com/fleschutz"><b>@fleschutz</b></a> for the <a href="https://github.com/fleschutz/PowerShell">mega collection of scripts</a>!</br>
- <a href="https://github.com/franklesniak"><b>@franklesniak</b></a> for lots of inspiring ideas!</br>
- <a href="https://github.com/StartAutomating"><b>@StartAutomating</b></a> for publishing modules like <a href="https://github.com/StartAutomating/wtx">wtx</a> and <a href="https://github.com/StartAutomating/ugit">ugit</a>.</br>
</p>
