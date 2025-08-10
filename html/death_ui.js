// Death UI JavaScript Controller
class DeathUI {
    constructor() {
        this.container = document.getElementById('death-container');
        this.timerMinutes = document.getElementById('timer-minutes');
        this.timerSeconds = document.getElementById('timer-seconds');
        this.signalText = document.getElementById('signal-text');
        this.respawnText = document.getElementById('respawn-text');
        this.warningText = document.getElementById('warning-text');
        this.respawnProgress = document.getElementById('respawn-progress');
        this.respawnFill = document.getElementById('respawn-fill');
        this.signalSent = document.getElementById('signal-sent');
        this.progressCircle = document.querySelector('.progress-ring__circle');
        this.holdProgressRing = document.querySelector('.hold-progress-ring');
        this.holdProgressCircle = document.getElementById('hold-progress-circle');
        this.holdProgressText = document.getElementById('hold-progress-text');
        this.holdTimer = document.getElementById('hold-timer');
        this.holdTotal = document.getElementById('hold-total');

        this.totalTime = 120; // Default 2 minutes
        this.remainingTime = 120;
        this.isRespawnPhase = false;
        this.isSignalSent = false;
        this.debugEnabled = false; // Will be set when config is received
        this.timerInterval = null;
        this.respawnInterval = null;

        this.circumference = 2 * Math.PI * 56; // radius = 56
        this.progressCircle.style.strokeDasharray = `${this.circumference} ${this.circumference}`;
        this.progressCircle.style.strokeDashoffset = this.circumference;

        this.holdCircumference = 2 * Math.PI * 50; // radius = 50 for hold circle
        this.holdProgressCircle.style.strokeDasharray = `${this.holdCircumference} ${this.holdCircumference}`;
        this.holdProgressCircle.style.strokeDashoffset = this.holdCircumference;

        this.setupEventListeners();
    }

    setupEventListeners() {
        // Listen for NUI messages from client
        window.addEventListener('message', (event) => {
            const data = event.data;

            switch(data.action) {
                case 'showDeathUI':
                    this.showUI(data.config);
                    break;
                case 'hideDeathUI':
                    this.hideUI();
                    break;
                case 'updateConfig':
                    this.updateTexts(data.config);
                    break;
                case 'signalSent':
                    this.showSignalSent();
                    break;
                case 'startRespawn':
                    this.startRespawnProgress(data.holdTime);
                    break;
                case 'stopRespawn':
                    this.stopRespawnProgress();
                    break;
                case 'toggleUIVisibility':
                    this.toggleVisibility(data.visible);
                    break;
                case 'startHoldProgress':
                    this.showHoldProgress();
                    break;
                case 'stopHoldProgress':
                    this.hideHoldProgress();
                    break;
                case 'updateHoldProgress':
                    this.updateHoldProgress(data);
                    break;
            }
        });

        // Key events are handled by Lua client script
    }

    // Debug print function
    debugPrint(...args) {
        if (this.debugEnabled) {
            console.log('DEBUG:', ...args);
        }
    }

    showUI(config) {
        this.totalTime = config.deathTimer || 120;
        this.remainingTime = this.totalTime;
        this.isRespawnPhase = false;
        this.isSignalSent = false;
        this.debugEnabled = config.debug || false;

        // Update texts from config
        this.updateTexts(config);

        // Reset UI state
        this.signalText.classList.remove('hidden');
        this.respawnText.classList.add('hidden');
        this.warningText.classList.add('hidden');
        this.respawnProgress.classList.add('hidden');
        this.signalSent.classList.add('hidden');

        // Show container with whoosh animation
        this.container.classList.remove('hidden');
        this.container.style.transform = 'translateX(-50%) scale(0.5) translateY(100px)';
        this.container.style.opacity = '0';

        // Animate in with whoosh effect
        setTimeout(() => {
            this.container.style.transition = 'all 0.6s cubic-bezier(0.175, 0.885, 0.32, 1.275)';
            this.container.style.transform = 'translateX(-50%) scale(1) translateY(0)';
            this.container.style.opacity = '1';
        }, 50);

        // Start timer
        this.startTimer();
    }

    hideUI() {
        this.container.classList.add('hidden');
        this.stopTimer();
        this.stopRespawnProgress();
    }

    toggleVisibility(visible) {
        if (visible) {
            this.container.style.opacity = '1';
            this.container.style.pointerEvents = 'auto';
        } else {
            this.container.style.opacity = '0';
            this.container.style.pointerEvents = 'none';
        }
    }

    updateTexts(config) {
        if (config.texts) {
            // Highlight the keys in the text
            const signalText = config.texts.sendSignal || "Изпратете сигнал към EMS натиснете [G]";
            const respawnText = config.texts.respawnText || "Задръжте [E] за да се респаунете";

            this.signalText.innerHTML = this.highlightKeys(signalText);
            this.respawnText.innerHTML = this.highlightKeys(respawnText);
            this.warningText.textContent = config.texts.itemWarning || "(Всички айтъми ще бъдат изтрити!)";
        }
    }

    highlightKeys(text) {
        // Replace [KEY] with highlighted spans
        return text.replace(/\[([A-Z])\]/g, '<span class="key-highlight">$1</span>');
    }

    startTimer() {
        this.updateTimerDisplay();
        this.updateProgress();

        this.timerInterval = setInterval(() => {
            this.remainingTime--;
            this.updateTimerDisplay();
            this.updateProgress();

            if (this.remainingTime <= 0) {
                this.onTimerExpired();
            }
        }, 1000);
    }

    stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    }

    updateTimerDisplay() {
        const minutes = Math.floor(this.remainingTime / 60);
        const seconds = this.remainingTime % 60;

        this.timerMinutes.textContent = minutes.toString().padStart(2, '0');
        this.timerSeconds.textContent = seconds.toString().padStart(2, '0');
    }

    updateProgress() {
        const progress = (this.totalTime - this.remainingTime) / this.totalTime;
        const offset = this.circumference - (progress * this.circumference);
        this.progressCircle.style.strokeDashoffset = offset;
    }

    onTimerExpired() {
        this.stopTimer();
        this.isRespawnPhase = true;

        // Update timer display to show "00:00"
        this.timerMinutes.textContent = '00';
        this.timerSeconds.textContent = '00';

        // Change timer circle color to red
        this.progressCircle.style.stroke = '#dc3545';
        this.progressCircle.style.strokeDashoffset = 0; // Full circle

        // Keep signal text visible, show respawn text
        this.respawnText.classList.remove('hidden');
        this.respawnText.classList.add('respawn-ready');
        this.warningText.classList.remove('hidden');

        // Notify Lua that timer expired
        try {
            fetch(`https://${GetParentResourceName()}/timerExpired`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            }).catch(() => {}); // Ignore fetch errors
        } catch (e) {
            // Ignore fetch errors
        }
    }

    sendSignal() {
        if (this.isSignalSent) return;

        this.isSignalSent = true;
        this.showSignalSent();

        // Send to client
        fetch(`https://${GetParentResourceName()}/sendEMSSignal`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    }

    showSignalSent() {
        this.signalSent.classList.remove('hidden');

        // Auto-hide after 3 seconds
        setTimeout(() => {
            this.signalSent.classList.add('hidden');
        }, 3000);
    }

    startRespawnHold() {
        if (!this.isRespawnPhase) return;

        fetch(`https://${GetParentResourceName()}/startRespawnHold`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    }

    stopRespawnHold() {
        fetch(`https://${GetParentResourceName()}/stopRespawnHold`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    }

    startRespawnProgress(holdTime) {
        this.respawnProgress.classList.remove('hidden');
        this.respawnFill.style.width = '0%';

        let progress = 0;
        const increment = 100 / (holdTime * 10); // 10 updates per second

        this.respawnInterval = setInterval(() => {
            progress += increment;
            this.respawnFill.style.width = `${Math.min(progress, 100)}%`;

            if (progress >= 100) {
                this.stopRespawnProgress();
                this.onRespawnComplete();
            }
        }, 100);
    }

    stopRespawnProgress() {
        if (this.respawnInterval) {
            clearInterval(this.respawnInterval);
            this.respawnInterval = null;
        }
        this.respawnProgress.classList.add('hidden');
    }

    onRespawnComplete() {
        fetch(`https://${GetParentResourceName()}/respawnPlayer`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    }

    showHoldProgress() {
        this.holdProgressText.classList.remove('hidden');
        this.holdTimer.textContent = '0.0s';
    }

    hideHoldProgress() {
        this.holdProgressText.classList.add('hidden');
    }

            updateHoldProgress(data) {
        // Debug: Check what data we received
        this.debugPrint("Received hold progress data:", data);

        // Make sure we have valid data
        if (!data || typeof data.progress === 'undefined' || typeof data.totalTime === 'undefined') {
            if (this.debugEnabled) {
                console.error("DEBUG: Invalid hold progress data received:", data);
            }
            return;
        }

        // Update the hold progress text with current time and total time
        const currentTime = (data.progress * data.totalTime).toFixed(1);
        const totalTime = data.totalTime.toFixed(1);

        this.holdTimer.textContent = currentTime + 's';
        this.holdTotal.textContent = totalTime + 's';

        this.debugPrint("Hold progress updated - progress:", data.progress, "current:", currentTime, "total:", totalTime);
    }
}

// Utility function for FiveM compatibility
function GetParentResourceName() {
    return window.invokeNative ? window.invokeNative('0x635DE9EF03DA6171') : 'qbx_ambulancejob';
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.deathUI = new DeathUI();
});
