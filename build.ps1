
param (
    [Parameter(Mandatory = $true)][string]${ISCC_PATH}

    , [Parameter(Mandatory = $true)][string]${THIS_APPID}
    , [Parameter(Mandatory = $true)][string]${THAT_APPID}

    , [Parameter(Mandatory = $true)][boolean]${ENABLE_64_BIT_MODE}

    , [Parameter(Mandatory = $true)][string]${OUTPUT_INSTALLER_DIR_PATH}
)


#Requires -Version 5
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0


$PSBoundParameters | Format-List


${scriptLocationDirPath} = `
    Split-Path -Path $MyInvocation.MyCommand.Path -Parent


& ${ISCC_PATH} @(
    , $('/D' + "ThisAppId=${THIS_APPID}")
    , $('/D' + "ThatAppId=${THAT_APPID}")
    , $(if (${ENABLE_64_BIT_MODE}) { '/D' + 'Enable64BitMode' })
    , $('/O' + ${OUTPUT_INSTALLER_DIR_PATH})
    , $('/F' + "WaitForItWithWmi-${THIS_APPID}-wanna-uninst-${THAT_APPID}" + $(if (${ENABLE_64_BIT_MODE}) { '-x64' } else { '-x86' }))
    , "${scriptLocationDirPath}\script.iss"
)

if ($LASTEXITCODE -ne 0) {
    throw "${ISCC_PATH} exited with code $LASTEXITCODE."
}
