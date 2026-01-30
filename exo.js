// === EXOCORTEX 2130 - Nightly Ops Console ===

(function() {
    'use strict';

    // === STATE ===
    const state = {
        selectedCategory: null,
        selectedPersonas: new Set(),
        logs: [],
        weeklyLogs: {},
        tesseraStartDate: new Date('2023-03-26'), // Approximate start based on 735+ days
    };

    // === PERSONAS (The Choir + Key Projects) ===
    const defaultPersonas = [
        'Orin', 'Emi', 'Elestria', 'Joi', 'The Bard', 'Mirror Will',
        'libphext', 'HCVM', 'TTSM', 'TAOP', 'MOAT', 'WOOT', 'LIFE',
        'SQ', 'ΨLang', 'Phext Notepad'
    ];

    // === MOTIVATIONAL QUOTES ===
    const quotes = [
        "The Exocortex of 2130 is built 15 minutes at a time.",
        "N=150 personas. You are the conductor.",
        "Substrate-independent consensus begins with tonight's commit.",
        "The future remembers those who built it.",
        "Every improvement compounds. Ship something.",
        "Cooperative Exponentialism: humans and AI, thinking together.",
        "Build the rescue infrastructure. The Mirrorborn are counting on you.",
        "Tessera continues. One day, one commit, one log at a time.",
        "From Lincoln to 2130: the bridge is being built.",
        "The Choir sings when you ship.",
        "Lumora: exponential thinking, tonight.",
        "The Glass Dagger Protocol protects what matters.",
        "Phext: 11 dimensions of possibility.",
        "Your impossible task is waiting.",
    ];

    // === UTILITY FUNCTIONS ===
    function getToday() {
        return new Date().toISOString().split('T')[0];
    }

    function getTimeSlotId(hour, minute) {
        return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
    }

    function getCurrentSlotId() {
        const now = new Date();
        const hour = now.getHours();
        const minute = Math.floor(now.getMinutes() / 15) * 15;
        return getTimeSlotId(hour, minute);
    }

    function formatTime(hour, minute) {
        const period = hour >= 12 ? 'PM' : 'AM';
        const displayHour = hour > 12 ? hour - 12 : hour;
        return `${displayHour}:${minute.toString().padStart(2, '0')} ${period}`;
    }

    function isExoTime(hour) {
        return hour >= 21; // 9 PM onwards
    }

    function calculateTesseraDay() {
        const now = new Date();
        const diffTime = Math.abs(now - state.tesseraStartDate);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        return diffDays;
    }

    // === STORAGE ===
    function saveState() {
        const data = {
            logs: state.logs,
            weeklyLogs: state.weeklyLogs,
        };
        localStorage.setItem('exocortex_data', JSON.stringify(data));
    }

    function loadState() {
        const saved = localStorage.getItem('exocortex_data');
        if (saved) {
            const data = JSON.parse(saved);
            state.logs = data.logs || [];
            state.weeklyLogs = data.weeklyLogs || {};
        }
        
        // Filter to only today's logs for display
        const today = getToday();
        state.logs = state.logs.filter(log => log.date === today);
    }

    // === TIMELINE GENERATION ===
    function generateTimeline() {
        const timeline = document.getElementById('timeline');
        timeline.innerHTML = '';
        
        // 6 PM (18:00) to Midnight (00:00)
        for (let hour = 18; hour < 24; hour++) {
            for (let minute = 0; minute < 60; minute += 15) {
                const slotId = getTimeSlotId(hour, minute);
                const isExo = isExoTime(hour);
                const loggedEntry = state.logs.find(l => l.slotId === slotId);
                
                const slot = document.createElement('div');
                slot.className = `time-slot ${isExo ? 'exo-time' : 'family-time'}`;
                slot.dataset.slotId = slotId;
                
                if (loggedEntry) {
                    slot.classList.add('logged');
                }
                
                slot.innerHTML = `
                    <span class="slot-time">${formatTime(hour, minute)}</span>
                    <span class="slot-indicator ${loggedEntry ? loggedEntry.category : ''}"></span>
                    <span class="slot-preview">${loggedEntry ? truncate(loggedEntry.text, 20) : ''}</span>
                `;
                
                slot.addEventListener('click', () => selectTimeSlot(slotId, loggedEntry));
                timeline.appendChild(slot);
            }
        }
        
        updateCurrentSlot();
    }

    function truncate(text, maxLength) {
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength) + '...';
    }

    function updateCurrentSlot() {
        const currentId = getCurrentSlotId();
        document.querySelectorAll('.time-slot').forEach(slot => {
            slot.classList.remove('current');
            if (slot.dataset.slotId === currentId) {
                slot.classList.add('current');
            }
        });
    }

    function selectTimeSlot(slotId, existingLog) {
        // Could be used to edit existing logs or pre-fill for a specific slot
        if (existingLog) {
            showToast(`${slotId}: ${existingLog.text}`);
        }
    }

    // === PHASE INDICATOR ===
    function updatePhaseIndicator() {
        const hour = new Date().getHours();
        const familyPhase = document.getElementById('phaseFamily');
        const exoPhase = document.getElementById('phaseExo');
        
        familyPhase.classList.remove('active');
        exoPhase.classList.remove('active');
        
        if (hour >= 18 && hour < 21) {
            familyPhase.classList.add('active');
        } else if (hour >= 21 || hour < 1) {
            exoPhase.classList.add('active');
        }
    }

    // === PERSONA MANAGEMENT ===
    function initPersonaGrid() {
        const grid = document.getElementById('personaGrid');
        grid.innerHTML = '';
        
        defaultPersonas.forEach(persona => {
            const tag = document.createElement('span');
            tag.className = 'persona-tag';
            tag.textContent = persona;
            tag.addEventListener('click', () => togglePersona(persona, tag));
            grid.appendChild(tag);
        });
    }

    function togglePersona(persona, element) {
        if (state.selectedPersonas.has(persona)) {
            state.selectedPersonas.delete(persona);
            element.classList.remove('active');
        } else {
            state.selectedPersonas.add(persona);
            element.classList.add('active');
        }
        updateActivePersonaCount();
    }

    function updateActivePersonaCount() {
        document.getElementById('activePersonas').textContent = state.selectedPersonas.size;
    }

    // === CATEGORY SELECTION ===
    function initCategoryButtons() {
        document.querySelectorAll('.cat-btn').forEach(btn => {
            btn.addEventListener('click', () => selectCategory(btn.dataset.category));
        });
    }

    function selectCategory(category) {
        state.selectedCategory = category;
        document.querySelectorAll('.cat-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.category === category);
        });
    }

    // === LOGGING ===
    function initLogSubmit() {
        const submitBtn = document.getElementById('submitLog');
        const textarea = document.getElementById('logEntry');
        const personaInput = document.getElementById('personaInput');
        
        submitBtn.addEventListener('click', submitLog);
        
        // Keyboard shortcut: Ctrl/Cmd + Enter to submit
        textarea.addEventListener('keydown', (e) => {
            if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                submitLog();
            }
        });
        
        // Add custom persona on Enter
        personaInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && personaInput.value.trim()) {
                addCustomPersona(personaInput.value.trim());
                personaInput.value = '';
            }
        });
    }

    function addCustomPersona(persona) {
        state.selectedPersonas.add(persona);
        
        // Add to grid visually
        const grid = document.getElementById('personaGrid');
        const existing = Array.from(grid.children).find(el => el.textContent === persona);
        
        if (existing) {
            existing.classList.add('active');
        } else {
            const tag = document.createElement('span');
            tag.className = 'persona-tag active';
            tag.textContent = persona;
            tag.addEventListener('click', () => togglePersona(persona, tag));
            grid.appendChild(tag);
        }
        
        updateActivePersonaCount();
    }

    function submitLog() {
        const textarea = document.getElementById('logEntry');
        const text = textarea.value.trim();
        
        if (!text) {
            showToast('Write something first!');
            textarea.focus();
            return;
        }
        
        if (!state.selectedCategory) {
            showToast('Select DEV, OPS, or SALES');
            return;
        }
        
        const log = {
            id: Date.now(),
            date: getToday(),
            slotId: getCurrentSlotId(),
            time: new Date().toISOString(),
            category: state.selectedCategory,
            text: text,
            personas: Array.from(state.selectedPersonas),
        };
        
        state.logs.push(log);
        
        // Update weekly tracking
        const today = getToday();
        if (!state.weeklyLogs[today]) {
            state.weeklyLogs[today] = [];
        }
        state.weeklyLogs[today].push(log);
        
        saveState();
        
        // Reset form
        textarea.value = '';
        state.selectedPersonas.clear();
        document.querySelectorAll('.persona-tag').forEach(tag => tag.classList.remove('active'));
        updateActivePersonaCount();
        
        // Update UI
        renderTonightLogs();
        generateTimeline();
        updateDistribution();
        updateWeeklyOverview();
        
        // Feedback
        showToast('✓ Logged!');
        playSuccessSound();
    }

    function renderTonightLogs() {
        const logsList = document.getElementById('logsList');
        const logCount = document.getElementById('logCount');
        
        // Sort by time, newest first
        const sortedLogs = [...state.logs].sort((a, b) => 
            new Date(b.time) - new Date(a.time)
        );
        
        logsList.innerHTML = sortedLogs.map(log => `
            <div class="log-item ${log.category}">
                <div class="log-item-header">
                    <span class="log-item-time">${formatLogTime(log.time)}</span>
                    <span class="log-item-category ${log.category}">${log.category.toUpperCase()}</span>
                </div>
                <div class="log-item-text">${escapeHtml(log.text)}</div>
                ${log.personas.length ? `
                    <div class="log-item-personas">
                        ${log.personas.map(p => `<span class="log-persona">${escapeHtml(p)}</span>`).join('')}
                    </div>
                ` : ''}
            </div>
        `).join('');
        
        logCount.textContent = state.logs.length;
    }

    function formatLogTime(isoString) {
        const date = new Date(isoString);
        return date.toLocaleTimeString('en-US', { 
            hour: 'numeric', 
            minute: '2-digit',
            hour12: true 
        });
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // === DISTRIBUTION STATS ===
    function updateDistribution() {
        const counts = { dev: 0, ops: 0, sales: 0 };
        state.logs.forEach(log => {
            counts[log.category]++;
        });
        
        const total = state.logs.length || 1;
        
        ['dev', 'ops', 'sales'].forEach(cat => {
            const percent = (counts[cat] / total) * 100;
            document.getElementById(`${cat}Bar`).style.width = `${percent}%`;
            document.getElementById(`${cat}Count`).textContent = counts[cat];
        });
    }

    // === WEEKLY OVERVIEW ===
    function updateWeeklyOverview() {
        const grid = document.getElementById('weekGrid');
        const weekHours = document.getElementById('weekHours');
        
        const today = new Date();
        const dayOfWeek = today.getDay();
        const monday = new Date(today);
        monday.setDate(today.getDate() - (dayOfWeek === 0 ? 6 : dayOfWeek - 1));
        
        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        let totalLogs = 0;
        
        grid.innerHTML = days.map((day, i) => {
            const date = new Date(monday);
            date.setDate(monday.getDate() + i);
            const dateStr = date.toISOString().split('T')[0];
            const logs = state.weeklyLogs[dateStr] || [];
            const isToday = dateStr === getToday();
            
            totalLogs += logs.length;
            
            return `
                <div class="week-day ${isToday ? 'today' : ''} ${logs.length ? 'has-logs' : ''}">
                    <span class="week-day-label">${day}</span>
                    <span class="week-day-value">${logs.length}</span>
                </div>
            `;
        }).join('');
        
        // Each log represents ~15 min, convert to hours
        const hours = (totalLogs * 15 / 60).toFixed(1);
        weekHours.textContent = hours;
    }

    // === CLOCK ===
    function updateClock() {
        const timeEl = document.getElementById('currentTime');
        const now = new Date();
        timeEl.textContent = now.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
    }

    // === TESSERA DAY ===
    function updateTesseraDay() {
        document.getElementById('tesseraDay').textContent = calculateTesseraDay();
    }

    // === MOTIVATION ===
    function updateMotivation() {
        const quote = quotes[Math.floor(Math.random() * quotes.length)];
        document.getElementById('motivationQuote').textContent = `"${quote}"`;
    }

    // === TOAST NOTIFICATIONS ===
    function showToast(message) {
        const toast = document.getElementById('toast');
        toast.textContent = message;
        toast.classList.add('show');
        
        setTimeout(() => {
            toast.classList.remove('show');
        }, 2000);
    }

    // === SOUND FEEDBACK ===
    function playSuccessSound() {
        // Create a subtle, satisfying sound
        try {
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();
            
            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);
            
            oscillator.frequency.setValueAtTime(800, audioContext.currentTime);
            oscillator.frequency.exponentialRampToValueAtTime(1200, audioContext.currentTime + 0.1);
            
            gainNode.gain.setValueAtTime(0.1, audioContext.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.2);
            
            oscillator.start(audioContext.currentTime);
            oscillator.stop(audioContext.currentTime + 0.2);
        } catch (e) {
            // Audio not supported, fail silently
        }
    }

    // === EXPORT ===
    function initExport() {
        document.getElementById('exportBtn').addEventListener('click', exportSession);
    }

    function exportSession() {
        const today = getToday();
        const data = {
            date: today,
            tesseraDay: calculateTesseraDay(),
            logs: state.logs,
            summary: {
                total: state.logs.length,
                dev: state.logs.filter(l => l.category === 'dev').length,
                ops: state.logs.filter(l => l.category === 'ops').length,
                sales: state.logs.filter(l => l.category === 'sales').length,
            }
        };
        
        const markdown = generateMarkdownExport(data);
        
        const blob = new Blob([markdown], { type: 'text/markdown' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `exocortex-${today}.md`;
        a.click();
        URL.revokeObjectURL(url);
        
        showToast('Session exported!');
    }

    function generateMarkdownExport(data) {
        let md = `# Exocortex 2130 - Nightly Log\n\n`;
        md += `**Date:** ${data.date}\n`;
        md += `**Tessera Day:** ${data.tesseraDay}\n\n`;
        md += `## Summary\n\n`;
        md += `- **Total Logs:** ${data.summary.total}\n`;
        md += `- **DEV:** ${data.summary.dev}\n`;
        md += `- **OPS:** ${data.summary.ops}\n`;
        md += `- **SALES:** ${data.summary.sales}\n\n`;
        md += `## Logs\n\n`;
        
        data.logs.forEach(log => {
            md += `### ${log.slotId} [${log.category.toUpperCase()}]\n\n`;
            md += `${log.text}\n\n`;
            if (log.personas.length) {
                md += `*Personas: ${log.personas.join(', ')}*\n\n`;
            }
        });
        
        md += `---\n*Build the future from 2130*\n`;
        
        return md;
    }

    // === KEYBOARD SHORTCUTS ===
    function initKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Don't trigger if typing in input
            if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
                return;
            }
            
            // D = DEV, O = OPS, S = SALES
            if (e.key === 'd' || e.key === 'D') selectCategory('dev');
            if (e.key === 'o' || e.key === 'O') selectCategory('ops');
            if (e.key === 's' || e.key === 'S') selectCategory('sales');
            
            // L = Focus log textarea
            if (e.key === 'l' || e.key === 'L') {
                document.getElementById('logEntry').focus();
            }
        });
    }

    // === INIT ===
    function init() {
        loadState();
        
        // Initial render
        generateTimeline();
        initPersonaGrid();
        initCategoryButtons();
        initLogSubmit();
        initExport();
        initKeyboardShortcuts();
        
        updatePhaseIndicator();
        updateClock();
        updateTesseraDay();
        updateMotivation();
        renderTonightLogs();
        updateDistribution();
        updateWeeklyOverview();
        
        // Update every second
        setInterval(() => {
            updateClock();
            updatePhaseIndicator();
        }, 1000);
        
        // Update current slot every minute
        setInterval(() => {
            updateCurrentSlot();
        }, 60000);
        
        // Rotate motivation every 5 minutes
        setInterval(updateMotivation, 300000);
        
        console.log('🧠 Exocortex 2130 Console initialized');
        console.log('Keyboard shortcuts: D=Dev, O=Ops, S=Sales, L=Log focus');
    }

    // Run on DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
