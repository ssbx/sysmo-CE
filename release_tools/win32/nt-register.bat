"!INSTALL_DIR!\sysmo-server\erts-6.3\bin\erlsrv.exe" ^
    add "Sysmo-NMS" -comment "Sysmo server service" ^
    -stopaction "init:stop()." ^
    -onfail restart ^
    -workdir "!INSTALL_DIR!\sysmo-server" ^
    -machine "!INSTALL_DIR!\sysmo-server\erts-6.3\bin\erl.exe" ^ 
    -priority high ^
    -args "-boot \"!INSTALL_DIR!\sysmo-server\releases\0.2.1\start\" -config \"!INSTALL_DIR!\sysmo-server\releases\0.2.1\sys\""

"!INSTALL_DIR!\sysmo-server\erts-6.3\bin\erlsrv.exe" start "Sysmo-NMS"
