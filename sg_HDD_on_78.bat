@echo off

setlocal enabledelayedexpansion

set n=1000

for /L %%i in (1,1,78) do (
    set /a n+=1
    echo sg_ses SCSI0:0,94,0 --clear=3:4:1 -D Disk!n:~-3!
    sg_ses SCSI0:0,94,0 --clear=3:4:1 -D Disk!n:~-3!

    ping 127.0.0.1 -n 26 > nul 

)
@echo on