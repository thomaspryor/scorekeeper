// Scorekeeper App
(function() {
  'use strict';

  // Color palette (Atari-style)
  const COLORS = [
    '#FF4444', '#FF9933', '#FFDD00', '#44DD44', '#99FF33', '#00DDDD',
    '#4488FF', '#AA44FF', '#FF66CC', '#AAAAAA', '#FFFFFF', '#333333'
  ];

  // State
  let state = {
    players: [],
    soundEnabled: true,
    sortMode: 'none' // 'none', 'asc', 'desc'
  };

  let editingPlayerId = null;
  let longPressTimer = null;
  let longPressInterval = null;

  // DOM Elements
  const playerList = document.getElementById('player-list');
  const editModal = document.getElementById('edit-modal');
  const colorPicker = document.getElementById('color-picker');
  const editNameInput = document.getElementById('edit-name');
  const btnAddPlayer = document.getElementById('btn-add-player');
  const btnReset = document.getElementById('btn-reset');
  const btnSort = document.getElementById('btn-sort');
  const btnSound = document.getElementById('btn-sound');
  const btnDeletePlayer = document.getElementById('btn-delete-player');
  const btnConfirmEdit = document.getElementById('btn-confirm-edit');

  // Initialize
  function init() {
    loadState();
    renderColorPicker();
    render();
    bindEvents();
    updateSoundButton();
  }

  // Storage
  function loadState() {
    try {
      const saved = localStorage.getItem('scorekeeper-state');
      if (saved) {
        const parsed = JSON.parse(saved);
        state = { ...state, ...parsed };
      }
    } catch (e) {
      console.warn('Failed to load state:', e);
    }
  }

  function saveState() {
    try {
      localStorage.setItem('scorekeeper-state', JSON.stringify(state));
    } catch (e) {
      console.warn('Failed to save state:', e);
    }
  }

  // Generate unique ID
  function generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  }

  // Get next available color
  function getNextColor() {
    const usedColors = new Set(state.players.map(p => p.color));
    for (const color of COLORS) {
      if (!usedColors.has(color)) return color;
    }
    return COLORS[state.players.length % COLORS.length];
  }

  // Add player
  function addPlayer() {
    const player = {
      id: generateId(),
      name: `Player ${state.players.length + 1}`,
      score: 0,
      color: getNextColor()
    };
    state.players.push(player);
    saveState();
    render();
    // Open edit modal for new player
    openEditModal(player.id);
  }

  // Remove player
  function removePlayer(id) {
    state.players = state.players.filter(p => p.id !== id);
    saveState();
    closeEditModal();
    render();
  }

  // Update player
  function updatePlayer(id, updates) {
    const player = state.players.find(p => p.id === id);
    if (player) {
      Object.assign(player, updates);
      saveState();
      render();
    }
  }

  // Change score
  function changeScore(id, delta) {
    const player = state.players.find(p => p.id === id);
    if (player) {
      player.score += delta;
      saveState();
      renderPlayerScore(id, player.score);
      playSound();
    }
  }

  // Reset all scores
  function resetScores() {
    if (state.players.length === 0) return;
    state.players.forEach(p => p.score = 0);
    saveState();
    render();
  }

  // Sort players
  function sortPlayers() {
    if (state.players.length < 2) return;

    // Cycle sort mode
    if (state.sortMode === 'none' || state.sortMode === 'asc') {
      state.sortMode = 'desc';
      state.players.sort((a, b) => b.score - a.score);
    } else {
      state.sortMode = 'asc';
      state.players.sort((a, b) => a.score - b.score);
    }

    saveState();
    render();
  }

  // Sound
  function playSound() {
    if (!state.soundEnabled) return;
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = ctx.createOscillator();
      const gain = ctx.createGain();
      oscillator.connect(gain);
      gain.connect(ctx.destination);
      oscillator.frequency.value = 800;
      oscillator.type = 'sine';
      gain.gain.setValueAtTime(0.1, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.1);
      oscillator.start(ctx.currentTime);
      oscillator.stop(ctx.currentTime + 0.1);
    } catch (e) {
      // Sound not supported
    }
  }

  function toggleSound() {
    state.soundEnabled = !state.soundEnabled;
    saveState();
    updateSoundButton();
    if (state.soundEnabled) playSound();
  }

  function updateSoundButton() {
    btnSound.classList.toggle('sound-off', !state.soundEnabled);
  }

  // Edit modal
  function openEditModal(playerId) {
    editingPlayerId = playerId;
    const player = state.players.find(p => p.id === playerId);
    if (!player) return;

    editNameInput.value = player.name;
    updateColorPickerSelection(player.color);
    editModal.hidden = false;
    editNameInput.focus();
    editNameInput.select();
  }

  function closeEditModal() {
    editModal.hidden = true;
    editingPlayerId = null;
  }

  function confirmEdit() {
    if (!editingPlayerId) return;
    const name = editNameInput.value.trim() || `Player ${state.players.findIndex(p => p.id === editingPlayerId) + 1}`;
    updatePlayer(editingPlayerId, { name });
    closeEditModal();
  }

  function selectColor(color) {
    if (!editingPlayerId) return;
    updatePlayer(editingPlayerId, { color });
    updateColorPickerSelection(color);
  }

  function updateColorPickerSelection(selectedColor) {
    colorPicker.querySelectorAll('.color-swatch').forEach(el => {
      el.classList.toggle('selected', el.dataset.color === selectedColor);
    });
  }

  // Render
  function render() {
    if (state.players.length === 0) {
      playerList.innerHTML = `
        <div class="empty-state">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M15 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm-9-2V7H4v3H1v2h3v3h2v-3h3v-2H6zm9 4c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
          </svg>
          <p>Tap + to add players</p>
        </div>
      `;
      return;
    }

    playerList.innerHTML = state.players.map(player => `
      <div class="player-row" data-id="${player.id}" style="background-color: ${player.color}; color: ${getTextColor(player.color)}">
        <span class="player-name">${escapeHtml(player.name)}</span>
        <span class="player-score" data-score-id="${player.id}">${player.score}</span>
        <button class="score-btn btn-minus" data-id="${player.id}" data-delta="-1" aria-label="Decrease score">−</button>
        <button class="score-btn btn-plus" data-id="${player.id}" data-delta="1" aria-label="Increase score">+</button>
      </div>
    `).join('');
  }

  function renderPlayerScore(id, score) {
    const el = document.querySelector(`[data-score-id="${id}"]`);
    if (el) {
      el.textContent = score;
      el.classList.remove('bump');
      void el.offsetWidth; // Trigger reflow
      el.classList.add('bump');
    }
  }

  function renderColorPicker() {
    colorPicker.innerHTML = COLORS.map(color => `
      <button class="color-swatch" data-color="${color}" style="background-color: ${color}" aria-label="Select ${color}"></button>
    `).join('');
  }

  // Determine text color for contrast
  function getTextColor(bgColor) {
    const hex = bgColor.replace('#', '');
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.5 ? '#000000' : '#FFFFFF';
  }

  // Escape HTML
  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // Long press handling
  function startLongPress(id, delta) {
    let count = 0;
    let delay = 150;

    longPressTimer = setTimeout(() => {
      longPressInterval = setInterval(() => {
        changeScore(id, delta);
        count++;
        // Accelerate
        if (count > 10 && delay > 50) {
          clearInterval(longPressInterval);
          delay = 50;
          longPressInterval = setInterval(() => changeScore(id, delta), delay);
        }
      }, delay);
    }, 300);
  }

  function stopLongPress() {
    if (longPressTimer) {
      clearTimeout(longPressTimer);
      longPressTimer = null;
    }
    if (longPressInterval) {
      clearInterval(longPressInterval);
      longPressInterval = null;
    }
  }

  // Event bindings
  function bindEvents() {
    // Add player
    btnAddPlayer.addEventListener('click', addPlayer);

    // Reset scores
    btnReset.addEventListener('click', resetScores);

    // Sort
    btnSort.addEventListener('click', sortPlayers);

    // Sound toggle
    btnSound.addEventListener('click', toggleSound);

    // Player list interactions
    playerList.addEventListener('click', (e) => {
      const scoreBtn = e.target.closest('.score-btn');
      if (scoreBtn) {
        e.stopPropagation();
        return; // Handled by mouseup/touchend
      }

      const row = e.target.closest('.player-row');
      if (row) {
        openEditModal(row.dataset.id);
      }
    });

    // Score buttons - tap
    playerList.addEventListener('mouseup', handleScoreButtonUp);
    playerList.addEventListener('touchend', handleScoreButtonUp);

    // Score buttons - long press start
    playerList.addEventListener('mousedown', handleScoreButtonDown);
    playerList.addEventListener('touchstart', handleScoreButtonDown, { passive: true });

    // Score buttons - long press cancel
    playerList.addEventListener('mouseleave', stopLongPress);
    playerList.addEventListener('touchcancel', stopLongPress);

    // Edit modal
    btnDeletePlayer.addEventListener('click', () => {
      if (editingPlayerId) removePlayer(editingPlayerId);
    });

    btnConfirmEdit.addEventListener('click', confirmEdit);

    editNameInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') confirmEdit();
      if (e.key === 'Escape') closeEditModal();
    });

    // Color picker
    colorPicker.addEventListener('click', (e) => {
      const swatch = e.target.closest('.color-swatch');
      if (swatch) selectColor(swatch.dataset.color);
    });

    // Close modal on backdrop click
    editModal.addEventListener('click', (e) => {
      if (e.target === editModal) closeEditModal();
    });

    // Prevent zoom on double tap
    document.addEventListener('touchend', (e) => {
      const now = Date.now();
      if (now - (document.lastTouchEnd || 0) < 300) {
        e.preventDefault();
      }
      document.lastTouchEnd = now;
    }, { passive: false });
  }

  function handleScoreButtonDown(e) {
    const btn = e.target.closest('.score-btn');
    if (!btn) return;

    const id = btn.dataset.id;
    const delta = parseInt(btn.dataset.delta, 10);
    startLongPress(id, delta);
  }

  function handleScoreButtonUp(e) {
    const btn = e.target.closest('.score-btn');
    stopLongPress();

    if (!btn) return;
    e.preventDefault();
    e.stopPropagation();

    const id = btn.dataset.id;
    const delta = parseInt(btn.dataset.delta, 10);

    // Only trigger single increment if no long press occurred
    if (!longPressInterval) {
      changeScore(id, delta);
    }
  }

  // Start app
  init();
})();
