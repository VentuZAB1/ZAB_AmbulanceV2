# QBX Ambulance Job - Enhanced Medical System 🚑

A comprehensive medical and EMS system for QBX Framework featuring advanced animations, custom death UI, and professional medical interactions.

## 🌟 Features Overview

### 🎬 ARS-Style Realistic Animations
- **Death Animation**: Persistent `dead_a` animation that stays active until revival
- **Multi-Stage Revival**: Professional medic revival animations using `getup_r_0`
- **Instant Patient Recovery**: Quick revival animation for better gameplay flow
- **Animation Protection**: Death animation persists through multiple deaths/damage

### 💀 Custom Death UI System
- **Circular Timer**: Configurable countdown (default: 2 minutes) before respawn option
- **Manual EMS Signal**: Press `[G]` to request help (not automatic)
- **Hold-to-Respawn**: Hold `[E]` after timer expires to respawn (configurable duration)
- **Multi-Language Support**: All UI text configurable via config
- **ESC to Hide**: Press ESC to hide UI temporarily for map viewing
- **Smooth Animations**: "Whoosh" entrance animation and smooth transitions

### 🏥 EMS Patient Examination System
- **Job-Locked ox_target**: Only ambulance workers can examine patients
- **Health Assessment**: Real-time health percentage display
- **Injury Detection**: Shows fractures, trauma, bleeding from qbx_medical
- **Treatment Options**: Bandage healing (25% health) and firstaid revival
- **Payment System**: EMS workers receive payment for treatments
- **Instant Updates**: Target system updates immediately with job/duty changes

### 🔧 Feature Toggle System
- **Modular Design**: Enable/disable features as needed
- **Duty System**: Optional on/off duty requirements
- **Vehicle Garages**: Toggle ambulance vehicle spawning
- **Helicopter Access**: Enable/disable helicopter spawning
- **Jail Hospital**: Optional jail medical facility

## 📁 Installation

1. **Download** the enhanced qbx_ambulancejob resource
2. **Place** in your resources folder
3. **Add** to your server.cfg:
   ```
   ensure qbx_ambulancejob
   ```
4. **Install Dependencies**:
   - qbx_core
   - qbx_medical
   - qbx_management
   - ox_lib
   - ox_target
   - ox_inventory

## ⚙️ Configuration

### Death UI Settings
```lua
-- config/shared.lua
deathUI = {
    enabled = true,
    debug = false, -- Toggle debug prints
    deathTimer = 120, -- Timer in seconds (2 minutes)
    respawnHoldTime = 5, -- Hold E duration for respawn
    signalKey = 'G', -- Key to send EMS signal
    respawnKey = 'E', -- Key to hold for respawn

    texts = {
        sendSignal = "Изпратете сигнал към EMS натиснете [G]",
        respawnText = "Задръжте [E] за да се респаунете",
        itemWarning = "(Всички айтъми ще бъдат изтрити!)",
        emsNotification = "Пострадал пациент: %s",
    }
}
```

### Payment System
```lua
-- config/shared.lua
bandagePayment = 200,      -- EMS payment for bandage healing
bandageHealAmount = 25,    -- Health restored by bandages (25%)
firstaidPayment = 1000,    -- EMS payment for revival
```

### Feature Toggles
```lua
-- config/shared.lua
features = {
    dutySystem = false,    -- Enable/disable duty system
    vehicles = false,      -- Enable/disable vehicle garages
    helicopters = false,   -- Enable/disable helicopters
    jailHospital = false,  -- Enable/disable jail hospital
}
```

## 🎮 How to Use

### For Players (When Dead)
1. **Death**: Player enters death state with custom UI
2. **Request Help**: Press `[G]` to send EMS signal (60s cooldown)
3. **Wait**: Timer counts down (configurable duration)
4. **Respawn**: After timer expires, hold `[E]` to respawn
5. **Map Access**: Press `ESC` to hide UI and view map

### For EMS Workers
1. **Target Patient**: Look at any player and press interaction key
2. **Examine**: Select "Examine Patient" from ox_target menu
3. **Assess Health**: View current health percentage and injuries
4. **Treat Injuries**:
   - **Bandages**: Heal 25% health (living players only)
   - **Firstaid**: Revive dead players
5. **Receive Payment**: Automatic payment for successful treatments
6. **EMS Alerts**: Receive notifications when players request help

### EMS Alert System
- **Sound Alert**: Beep notification when patient requests help
- **Map Blip**: Flickering blip showing patient location with RP name
- **Auto-Remove**: Blip disappears when patient is revived or disconnects

## 🔧 Technical Features

### Performance Optimizations
- **Smart Polling**: G key detection optimized for responsiveness vs performance
- **Conditional Loading**: Features only load when enabled
- **Efficient Timers**: Optimized wait times and thread management
- **Memory Management**: Proper cleanup and resource management

### Animation System
- **Persistent Death**: `dead_a` animation stays active until revival
- **Advanced Flags**: Animation protection from interruption (1|2|16|32)
- **State Management**: Proper handling of death states and transitions
- **Recovery Animations**: Smooth transition from death to alive state

### Integration Compatibility
- **QBX Framework**: Full compatibility with QBX core systems
- **qbx_medical Override**: Patches medical system for seamless integration
- **ox_lib Integration**: Modern UI notifications and context menus
- **Export System**: Clean exports for other resources to interact

## 🎨 UI Customization

### Death UI Styling
- **Modern Design**: Clean, professional medical UI
- **Responsive Layout**: Works on different screen sizes
- **Color Scheme**: Medical blue theme with red emergency accents
- **Typography**: Clear, readable fonts for emergency situations
- **Positioning**: Bottom-center placement for optimal visibility

### Key Highlighting
- **Visual Feedback**: Keys are highlighted in UI text
- **Status Indicators**: Clear indication of available actions
- **Progress Display**: Hold progress bar for respawn action
- **Timer Display**: Clear countdown with MM:SS format

## 🛠️ Advanced Configuration

### Hospital Locations
```lua
-- config/shared.lua
hospitals = {
    pillbox = {
        coords = vec3(350, -580, 43),
        checkIn = vec3(308.19, -595.35, 43.29),
        beds = {
            {coords = vec4(353.1, -584.6, 43.11, 152.08), model = 1631638868},
            -- ... more beds
        }
    },
    -- ... more hospitals
}
```

### Debug System
- **Toggle Debug**: Enable/disable debug prints via config
- **Console Logging**: F8 console debug information
- **Admin Commands**: `/forcerespawn` and `/debugdeath` for testing

## 🔄 Recent Changes & Enhancements

### Version 2.0 Features
- ✅ **ARS-Style Animations**: Realistic death and revival animations
- ✅ **Custom Death UI**: Professional medical emergency interface
- ✅ **EMS Payment System**: QBX-compatible payment for medical services
- ✅ **Feature Toggles**: Modular system for enabling/disabling features
- ✅ **Performance**: Optimized for low resource usage
- ✅ **Bug Fixes**: Resolved animation persistence and UI issues

### Removed Features (Configurable)
- 🚫 **Jail Hospital**: Removed by default (can re-enable)
- 🚫 **Duty System**: Disabled by default (can re-enable)
- 🚫 **Vehicle Garages**: Disabled by default (can re-enable)
- 🚫 **Helicopter Access**: Disabled by default (can re-enable)

## 🐛 Troubleshooting

### Common Issues
1. **Double ox_target**: Fixed duplicate patient examination options
2. **Animation Issues**: Ensured persistent death animation
3. **Timer Problems**: Resolved respawn timer display issues
4. **Key Conflicts**: Proper control action management

### Debug Commands
```
/forcerespawn - Force respawn for testing
/debugdeath - Toggle death UI for testing
```

## 📞 Support & Compatibility

### Framework Requirements
- **QBX Core**: Latest version required
- **QBX Medical**: Compatible with medical system
- **OX Resources**: ox_lib, ox_target, ox_inventory

### Server Settings
- Ensure proper permissions for ambulance job
- Configure hospital locations for your map
- Adjust payment amounts for server economy

## 🏆 Credits

Made by your dearest VentuZAB and his best colleague, CURSOR

### Special Features
- Bulgarian language support (configurable)
- Professional medical animations
- Modern UI design principles
- Performance-optimized code

---

**Version**: 2.0 Enhanced
**Framework**: QBX
**License**: Custom Medical System
**Support**: Professional FiveM Development

