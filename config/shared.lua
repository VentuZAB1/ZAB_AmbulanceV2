return {
    checkInCost = 2000, -- Price for using the hospital check-in system
    minForCheckIn = 2, -- Minimum number of people with the ambulance job to prevent the check-in system from being used

    -- EMS Payment System
    bandagePayment = 200, -- Payment for EMS workers when healing patients with bandages
    bandageHealAmount = 25, -- Percentage of health restored by bandages (25% = 25)
    firstaidPayment = 1000, -- Payment for EMS workers when reviving patients with firstaid

    -- Feature Toggles (enable/disable features)
    features = {
        dutySystem = false, -- Enable/disable duty on/off system
        vehicles = false, -- Enable/disable ambulance vehicle spawning
        helicopters = false, -- Enable/disable helicopter spawning
        jailHospital = false, -- Enable/disable jail hospital beds
    },

    -- Death UI System
    deathUI = {
        enabled = true,
        debug = false, -- Set to true to enable debug prints in F8 console
        deathTimer = 120, -- Timer in seconds before respawn option appears (2 minutes = 120)
        respawnHoldTime = 5, -- Time in seconds to hold E for respawn
        signalKey = 'G', -- Key to send EMS signal
        respawnKey = 'E', -- Key to hold for respawn

        -- UI Text (configurable for different languages)
        texts = {
            sendSignal = "Изпратете сигнал към EMS натиснете [G]",
            respawnText = "Задръжте [E] за да се респаунете",
            itemWarning = "(Всички айтъми ще бъдат изтрити!)",
            emsNotification = "Пострадал пациент: %s", -- %s will be replaced with RP name
        },

        -- ox_lib Notification Configuration
        oxNotifications = {
            emsAlert = {
                title = "EMS ALERT",
                description = "Пострадал пациент: %s", -- %s will be replaced with RP name
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
            },
            signalSent = {
                description = "Сигнал изпратен към EMS служителите",
                type = "success"
            },
            noEmsOnline = {
                description = "Няма налични EMS служители",
                type = "error"
            },
            rateLimited = {
                description = "You are sending too many signals. Please wait.",
                type = "error"
            },
            cooldownRemaining = {
                description = "COOLDOWN - %d seconds left till you can request help again...",
                type = "error"
            },
            -- Additional EMS notifications
            patientRevived = {
                description = "Patient revived successfully! You earned $%d",
                type = "success"
            },
            youWereRevived = {
                description = "You have been revived by a paramedic",
                type = "success"
            },
            emsDown = {
                title = "EMS DOWN",
                description = "Doctor %s Down", -- %s will be replaced with lastname
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
        }
    },

    locations = { -- Various interaction points
        -- DISABLED: duty = {
        --     vec3(311.18, -599.25, 43.29),
        --     vec3(-254.88, 6324.5, 32.58),
        -- },
        -- DISABLED: vehicle = {
        --     vec4(294.578, -574.761, 43.179, 35.79),
        --     vec4(-234.28, 6329.16, 32.15, 222.5),
        -- },
        -- DISABLED: helicopter = {
        --     vec4(351.58, -587.45, 74.16, 160.5),
        --     vec4(-475.43, 5988.353, 31.716, 31.34),
        -- },
        armory = {
            {
                shopType = 'AmbulanceArmory',
                name = 'Armory',
                groups = { ambulance = 0 },
                inventory = {
                    { name = 'radio', price = 0 },
                    { name = 'bandage', price = 0 },
                    { name = 'painkillers', price = 0 },
                    { name = 'firstaid', price = 0 },
                    { name = 'weapon_flashlight', price = 0 },
                    { name = 'weapon_fireextinguisher', price = 0 },
                },
                locations = {
                    vec3(309.93, -602.94, 43.29)
                }
            }
        },
        roof = {
            vec3(338.54, -583.88, 74.17),
        },
        main = {
            vec3(298.62, -599.66, 43.29),
        },
        stash = {
            {
                name = 'ambulanceStash',
                label = 'Personal stash',
                weight = 100000,
                slots = 30,
                groups = { ambulance = 0 },
                owner = true, -- Set to false for group stash
                location = vec3(309.78, -596.6, 43.29)
            }
        },

        ---@class Bed
        ---@field coords vector4
        ---@field model number

        ---@type table<string, {coords: vector3, checkIn?: vector3|vector3[], beds: Bed[]}>
        hospitals = {
            pillbox = {
                coords = vec3(350, -580, 43),
                checkIn = vec3(308.19, -595.35, 43.29),
                beds = {
                    {coords = vec4(353.1, -584.6, 43.11, 152.08), model = 1631638868},
                    {coords = vec4(356.79, -585.86, 43.11, 152.08), model = 1631638868},
                    {coords = vec4(354.12, -593.12, 43.1, 336.32), model = 2117668672},
                    {coords = vec4(350.79, -591.8, 43.1, 336.32), model = 2117668672},
                    {coords = vec4(346.99, -590.48, 43.1, 336.32), model = 2117668672},
                    {coords = vec4(360.32, -587.19, 43.02, 152.08), model = -1091386327},
                    {coords = vec4(349.82, -583.33, 43.02, 152.08), model = -1091386327},
                    {coords = vec4(326.98, -576.17, 43.02, 152.08), model = -1091386327},
                },
            },
            paleto = {
                coords = vec3(-250, 6315, 32),
                checkIn = vec3(-254.54, 6331.78, 32.43),
                beds = {
                    {coords = vec4(-252.43, 6312.25, 32.34, 313.48), model = 2117668672},
                    {coords = vec4(-247.04, 6317.95, 32.34, 134.64), model = 2117668672},
                    {coords = vec4(-255.98, 6315.67, 32.34, 313.91), model = 2117668672},
                },
            },
            -- REMOVED: jail hospital (can be re-enabled in features.jailHospital)
            -- jail = {
            --     coords = vec3(1761, 2600, 46),
            --     beds = {
            --         {coords = vec4(1761.96, 2597.74, 45.66, 270.14), model = 2117668672},
            --         {coords = vec4(1761.96, 2591.51, 45.66, 269.8), model = 2117668672},
            --         {coords = vec4(1771.8, 2598.02, 45.66, 89.05), model = 2117668672},
            --         {coords = vec4(1771.85, 2591.85, 45.66, 91.51), model = 2117668672},
            --     },
            -- },
        },

        stations = {
            {label = 'Pillbox Hospital', coords = vec4(304.27, -600.33, 43.28, 272.249)},
        }
    },
}