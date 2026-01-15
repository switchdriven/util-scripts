#!/usr/bin/env osascript

# AppleScript sample for net-port.rb integration
# Usage: osascript test-net-port-applescript.applescript

-- Get Wi-Fi SSID
on getWiFiSSID()
    try
        set currentSSID to (do shell script "/Users/junya/Dev/util-scripts/net-port.rb ssid Wi-Fi")
        return currentSSID
    on error errMsg
        return "Error: " & errMsg
    end try
end getWiFiSSID

-- Get Wi-Fi device name
on getWiFiDevice()
    try
        set wifiDevice to (do shell script "/Users/junya/Dev/util-scripts/net-port.rb device Wi-Fi")
        return wifiDevice
    on error errMsg
        return "Error: " & errMsg
    end try
end getWiFiDevice

-- Get Wi-Fi status
on getWiFiStatus()
    try
        set wifiStatus to (do shell script "/Users/junya/Dev/util-scripts/net-port.rb status Wi-Fi")
        return wifiStatus
    on error errMsg
        return "Error: " & errMsg
    end try
end getWiFiStatus

-- Get Wi-Fi IP address
on getWiFiAddr()
    try
        set wifiAddr to (do shell script "/Users/junya/Dev/util-scripts/net-port.rb addr Wi-Fi")
        return wifiAddr
    on error errMsg
        return "Error: " & errMsg
    end try
end getWiFiAddr

-- Get all port information as JSON
on getPortListJSON()
    try
        set portList to (do shell script "/Users/junya/Dev/util-scripts/net-port.rb --format json list")
        return portList
    on error errMsg
        return "Error: " & errMsg
    end try
end getPortListJSON

-- Main test execution
on run
    display notification "Wi-Fi SSID: " & getWiFiSSID() with title "net-port.rb Test"

    set deviceName to getWiFiDevice()
    display notification "Wi-Fi Device: " & deviceName with title "net-port.rb Test"

    set connectionStatus to getWiFiStatus()
    display notification "Wi-Fi Status: " & connectionStatus with title "net-port.rb Test"

    set ipAddress to getWiFiAddr()
    display notification "Wi-Fi IP: " & ipAddress with title "net-port.rb Test"

    -- Show summary in dialog
    set summary to "Wi-Fi Information:" & return & return & ¬
        "SSID: " & getWiFiSSID() & return & ¬
        "Device: " & getWiFiDevice() & return & ¬
        "Status: " & getWiFiStatus() & return & ¬
        "IP Address: " & getWiFiAddr()

    display dialog summary buttons {"OK"} default button 1 with title "Network Port Info"
end run
