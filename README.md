# InnoSetup Uninstall the Old Version 1

This is a story of the `_iu14D2N.tmp` file.

## Build

```powershell
& 'path\to\build.ps1' `
    -ISCC_PATH 'path\to\ISCC.exe' `
    -THIS_APPID 'the-app-id-of-this-app' `
    -THAT_APPID 'the-app-id-of-the-app-to-be-uninstalled' `
    -ENABLE_64_BIT_MODE $true `
    -OUTPUT_INSTALLER_DIR_PATH 'path\to\output\dir'
```
