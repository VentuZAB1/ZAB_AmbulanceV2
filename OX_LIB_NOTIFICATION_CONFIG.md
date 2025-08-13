# OX_LIB Notification Configuration Guide

This guide explains how to customize the ox_lib notification texts for EMS signals and alerts in the ambulance job system.

## Configuration Location

All ox_lib notification configurations are located in `config/shared.lua` under the `deathUI.oxNotifications` section.

## Available Notification Types

### 1. EMS Alert (emsAlert)
Sent to all online EMS workers when a patient sends a signal.

```lua
emsAlert = {
    title = "EMS ALERT",
    description = "Пострадал пациент: %s", -- %s will be replaced with patient's RP name
    type = "inform",
    position = "bottom-right",
    duration = 8000,
    style = {
        backgroundColor = "#8b45c1",
        color = "#ffffff",
        [".description"] = {
            color = "#ffffff"
        }
    }
}
```

### 2. Signal Sent (signalSent)
Sent to the patient when they successfully send an EMS signal.

```lua
signalSent = {
    description = "Сигнал изпратен към EMS служителите",
    type = "success"
}
```

### 3. No EMS Online (noEmsOnline)
Sent when no EMS workers are available online.

```lua
noEmsOnline = {
    description = "Няма налични EMS служители",
    type = "error"
}
```

### 4. Rate Limited (rateLimited)
Sent when a player is sending signals too frequently.

```lua
rateLimited = {
    description = "You are sending too many signals. Please wait.",
    type = "error"
}
```

### 5. Cooldown Remaining (cooldownRemaining)
Sent when a player tries to send a signal while on cooldown.

```lua
cooldownRemaining = {
    description = "COOLDOWN - %d seconds left till you can request help again...", -- %d will be replaced with remaining seconds
    type = "error"
}
```

### 6. Patient Revived (patientRevived)
Sent to EMS worker when they successfully revive a patient.

```lua
patientRevived = {
    description = "Patient revived successfully! You earned $%d", -- %d will be replaced with payment amount
    type = "success"
}
```

### 7. You Were Revived (youWereRevived)
Sent to the patient when they are revived by an EMS worker.

```lua
youWereRevived = {
    description = "You have been revived by a paramedic",
    type = "success"
}
```

### 8. EMS Down (emsDown)
Sent to EMS workers when another EMS worker goes down.

```lua
emsDown = {
    title = "EMS DOWN",
    description = "Doctor %s Down", -- %s will be replaced with EMS worker's lastname
    type = "error",
    position = "bottom-right",
    duration = 5000,
    style = {
        backgroundColor = "#dc2626",
        color = "#ffffff",
        [".description"] = {
            color = "#ffffff"
        }
    }
}
```

## Customization Options

### Basic Properties
- `title`: The title of the notification (optional)
- `description`: The main text content (supports string formatting)
- `type`: Notification type (`"success"`, `"error"`, `"info"`, `"inform"`, `"warning"`)
- `position`: Position on screen (default: `"bottom-right"`)
- `duration`: How long to show in milliseconds (default: 5000)

### Styling
The `style` object allows you to customize colors and appearance:

```lua
style = {
    backgroundColor = "#8b45c1", -- Background color
    color = "#ffffff",           -- Text color
    [".description"] = {         -- Specific styling for description
        color = "#ffffff"
    }
}
```

### String Formatting
Some notifications support dynamic content using string formatting:
- `%s` for string values (names, text)
- `%d` for number values (time, money)

## Examples

### Changing the EMS Alert Color
```lua
emsAlert = {
    title = "EMERGENCY CALL",
    description = "Patient needs help: %s",
    type = "inform",
    position = "center",
    duration = 10000,
    style = {
        backgroundColor = "#dc2626", -- Red background
        color = "#ffffff"
    }
}
```

### Customizing Languages
```lua
signalSent = {
    description = "Your emergency signal has been sent to medical personnel",
    type = "success"
},
noEmsOnline = {
    description = "No medical personnel are currently available",
    type = "error"
}
```

### Adjusting Timing
```lua
emsAlert = {
    title = "URGENT MEDICAL REQUEST",
    description = "Patient: %s requires immediate assistance",
    type = "inform",
    position = "top",
    duration = 15000, -- Show for 15 seconds
    style = {
        backgroundColor = "#ff6b35",
        color = "#ffffff"
    }
}
```

## Notes

1. After making changes to the configuration, restart the resource for changes to take effect.
2. All styling follows CSS color formats (hex codes, RGB, etc.).
3. Position options include: `"top"`, `"top-right"`, `"top-left"`, `"bottom"`, `"bottom-right"`, `"bottom-left"`, `"center"`
4. Duration is in milliseconds (1000 = 1 second)
5. The formatting placeholders (`%s`, `%d`) are automatically filled by the script - don't remove them unless you want static text.
