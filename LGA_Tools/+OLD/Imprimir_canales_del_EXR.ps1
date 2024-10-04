#Este filtra a los canales RGBA:

C:\Portable\EXR_tools\OpenEXR\exrheader.exe "C:\Portable\EXR_tools\test.exr" | 
    Select-String -Pattern "^\s+(\w+)" | 
    ForEach-Object { $_.Matches.Groups[1].Value } | 
    Where-Object { $_ -notmatch '^[ARGB]$' } | 
    ForEach-Object { $_.Split('.')[0] } | 
    Select-Object -Unique > canales_unicos.txt



# Este no:

C:\Portable\EXR_tools\OpenEXR\exrheader.exe "C:\Portable\EXR_tools\test.exr" | 
    Select-String -Pattern "^\s+(\w+)" | 
    ForEach-Object { $_.Matches.Groups[1].Value } | 
    ForEach-Object { $_.Split('.')[0] } | 
    Select-Object -Unique