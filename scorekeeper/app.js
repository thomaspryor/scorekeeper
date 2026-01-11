// Scorekeeper App
(function() {
  'use strict';

  // Color palette - matches original Scorekeeper XL order
  const COLORS = [
    '#FF4136', // Red
    '#FF851B', // Orange
    '#FFDC00', // Yellow
    '#2ECC40', // Green
    '#01FF70', // Lime
    '#39CCCC', // Cyan
    '#0074D9', // Blue
    '#B10DC9', // Purple
    '#F012BE', // Pink/Magenta
    '#AAAAAA', // Gray
    '#111111', // Black
    '#FFFFFF', // White
  ];

  // State
  let state = {
    players: [],
    soundEnabled: true,
    isSorted: false,
    originalOrder: [] // Array of player IDs in original (unsorted) order
  };

  // Undo stack
  let undoStack = [];
  const MAX_UNDO = 50;

  // Track running deltas per player (for showing "0 + 10 = 10")
  let playerDeltas = {}; // playerId -> { baseScore, delta, timeout }

  let editingPlayerId = null;
  let longPressTimer = null;
  let longPressInterval = null;
  let wasLongPress = false; // Track if long press happened
  let audioContext = null;

  // DOM Elements
  const playerList = document.getElementById('player-list');
  const editModal = document.getElementById('edit-modal');
  const colorPicker = document.getElementById('color-picker');
  const editNameInput = document.getElementById('edit-name');
  const btnAddPlayer = document.getElementById('btn-add-player');
  const btnUndo = document.getElementById('btn-undo');
  const btnReset = document.getElementById('btn-reset');
  const btnSort = document.getElementById('btn-sort');
  const btnSound = document.getElementById('btn-sound');
  const btnDeletePlayer = document.getElementById('btn-delete-player');
  const btnConfirmEdit = document.getElementById('btn-confirm-edit');

  // Initialize
  function init() {
    loadState();
    initAudio();
    renderColorPicker();
    render();
    bindEvents();
    updateSoundButton();
    updateUndoButton();
    updateSortButton();
  }

  // Audio - Safari requires user gesture to create AudioContext
  function initAudio() {
    const createContext = () => {
      if (!audioContext) {
        audioContext = new (window.AudioContext || window.webkitAudioContext)();
      }
      if (audioContext.state === 'suspended') {
        audioContext.resume();
      }
    };

    document.addEventListener('touchstart', createContext, { once: true });
    document.addEventListener('click', createContext, { once: true });
  }

  // Storage
  function loadState() {
    try {
      const saved = localStorage.getItem('scorekeeper-state');
      if (saved) {
        const parsed = JSON.parse(saved);
        state = { ...state, ...parsed };
        // If no original order saved, initialize from current player order
        if (!state.originalOrder || state.originalOrder.length === 0) {
          state.originalOrder = state.players.map(p => p.id);
        }
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

  // Undo
  function pushUndo() {
    undoStack.push({
      players: JSON.stringify(state.players),
      originalOrder: [...state.originalOrder],
      isSorted: state.isSorted
    });
    if (undoStack.length > MAX_UNDO) {
      undoStack.shift();
    }
    updateUndoButton();
  }

  function undo() {
    if (undoStack.length === 0) return;
    const snapshot = undoStack.pop();
    state.players = JSON.parse(snapshot.players);
    state.originalOrder = snapshot.originalOrder;
    state.isSorted = snapshot.isSorted;
    saveState();
    clearAllDeltas();
    render();
    updateUndoButton();
    updateSortButton();
  }

  function updateUndoButton() {
    btnUndo.disabled = undoStack.length === 0;
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
    pushUndo();
    const player = {
      id: generateId(),
      name: '',
      score: 0,
      color: getNextColor()
    };
    state.players.push(player);
    state.originalOrder.push(player.id); // Add to original order
    state.isSorted = false; // Adding a player breaks sort
    saveState();
    render();
    updateSortButton();
    openEditModal(player.id, true); // true = new player, focus input
  }

  // Remove player
  function removePlayer(id) {
    const player = state.players.find(p => p.id === id);
    if (!player) return;

    // Confirm deletion
    if (!confirm(`Delete ${player.name || 'this player'}?`)) {
      return;
    }

    pushUndo();
    state.players = state.players.filter(p => p.id !== id);
    state.originalOrder = state.originalOrder.filter(pid => pid !== id);
    delete playerDeltas[id];
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

  // Change score with running total display
  function changeScore(id, delta, isLongPress = false) {
    const player = state.players.find(p => p.id === id);
    if (!player) return;

    // Only push undo at start of a change sequence (not during long press)
    if (!isLongPress && !playerDeltas[id]) {
      pushUndo();
    }

    // Track delta for running total display
    if (!playerDeltas[id]) {
      playerDeltas[id] = {
        baseScore: player.score,
        delta: 0,
        timeout: null
      };
    }

    if (playerDeltas[id].timeout) {
      clearTimeout(playerDeltas[id].timeout);
    }

    playerDeltas[id].delta += delta;
    player.score += delta;
    saveState();

    renderPlayerScore(id, player.score, playerDeltas[id].baseScore, playerDeltas[id].delta);
    playSound();

    playerDeltas[id].timeout = setTimeout(() => {
      clearDelta(id);
    }, 2000);
  }

  function clearDelta(id) {
    if (playerDeltas[id]) {
      clearTimeout(playerDeltas[id].timeout);
      delete playerDeltas[id];
      const player = state.players.find(p => p.id === id);
      if (player) {
        renderPlayerScore(id, player.score, null, null);
      }
    }
  }

  function clearAllDeltas() {
    Object.keys(playerDeltas).forEach(id => {
      if (playerDeltas[id].timeout) {
        clearTimeout(playerDeltas[id].timeout);
      }
    });
    playerDeltas = {};
  }

  // Reset all scores
  function resetScores() {
    if (state.players.length === 0) return;
    if (state.players.every(p => p.score === 0)) return;

    if (!confirm('Reset all scores to 0?')) {
      return;
    }

    pushUndo();
    state.players.forEach(p => p.score = 0);
    clearAllDeltas();
    saveState();
    render();
  }

  // Sort/Unsort players
  function toggleSort() {
    if (state.players.length < 2) return;

    pushUndo();

    if (state.isSorted) {
      // Unsort - restore original order
      const playerMap = new Map(state.players.map(p => [p.id, p]));
      state.players = state.originalOrder
        .filter(id => playerMap.has(id))
        .map(id => playerMap.get(id));
      state.isSorted = false;
    } else {
      // Sort high to low
      state.players.sort((a, b) => b.score - a.score);
      state.isSorted = true;
    }

    saveState();
    render();
    updateSortButton();
  }

  function updateSortButton() {
    const label = btnSort.querySelector('.sort-label');
    if (label) {
      label.textContent = state.isSorted ? 'Unsort' : 'Sort';
    }
  }

  // Sound
  function playSound() {
    if (!state.soundEnabled || !audioContext) return;

    try {
      if (audioContext.state === 'suspended') {
        audioContext.resume();
      }

      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      oscillator.connect(gain);
      gain.connect(audioContext.destination);
      oscillator.frequency.value = 880;
      oscillator.type = 'sine';
      gain.gain.setValueAtTime(0.1, audioContext.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + 0.08);
      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 0.08);
    } catch (e) {
      // Sound not supported
    }
  }

  function toggleSound() {
    state.soundEnabled = !state.soundEnabled;
    saveState();
    updateSoundButton();
    if (state.soundEnabled) {
      if (!audioContext) {
        audioContext = new (window.AudioContext || window.webkitAudioContext)();
      }
      playSound();
    }
  }

  function updateSoundButton() {
    btnSound.classList.toggle('sound-off', !state.soundEnabled);
  }

  // Edit modal
  function openEditModal(playerId, isNewPlayer = false) {
    editingPlayerId = playerId;
    const player = state.players.find(p => p.id === playerId);
    if (!player) return;

    editNameInput.value = player.name;
    updateColorPickerSelection(player.color);
    editModal.hidden = false;

    // Focus and show keyboard - use longer delay for Safari iOS
    setTimeout(() => {
      editNameInput.focus();
      // For new players, select all; for existing, put cursor at end
      if (isNewPlayer || !player.name) {
        editNameInput.value = ''; // Clear for new player
        editNameInput.placeholder = `Player ${state.players.findIndex(p => p.id === playerId) + 1}`;
      } else {
        editNameInput.select();
      }
    }, 100);
  }

  function closeEditModal() {
    // Auto-save name on close
    if (editingPlayerId) {
      const name = editNameInput.value.trim();
      const playerIndex = state.players.findIndex(p => p.id === editingPlayerId);
      const finalName = name || `Player ${playerIndex + 1}`;
      updatePlayer(editingPlayerId, { name: finalName });
    }
    editModal.hidden = true;
    editingPlayerId = null;
  }

  function confirmEdit() {
    if (!editingPlayerId) return;
    const name = editNameInput.value.trim();
    const playerIndex = state.players.findIndex(p => p.id === editingPlayerId);
    const finalName = name || `Player ${playerIndex + 1}`;
    updatePlayer(editingPlayerId, { name: finalName });
    editModal.hidden = true;
    editingPlayerId = null;
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
            <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
          </svg>
          <p>Tap + to add players</p>
        </div>
      `;
      return;
    }

    playerList.innerHTML = state.players.map(player => {
      const deltaInfo = playerDeltas[player.id];
      const showDelta = deltaInfo && deltaInfo.delta !== 0;
      const deltaText = showDelta
        ? `${deltaInfo.baseScore} ${deltaInfo.delta >= 0 ? '+' : '−'} ${Math.abs(deltaInfo.delta)} =`
        : '';
      const displayName = player.name || `Player ${state.players.findIndex(p => p.id === player.id) + 1}`;

      return `
        <div class="player-row" data-id="${player.id}" style="background-color: ${player.color}; color: ${getTextColor(player.color)}">
          <span class="player-name">${escapeHtml(displayName)}</span>
          <div class="score-display">
            <span class="score-delta ${showDelta ? 'visible' : ''}" data-delta-id="${player.id}">${deltaText}</span>
            <span class="player-score" data-score-id="${player.id}">${player.score}</span>
          </div>
          <button class="score-btn btn-minus" data-id="${player.id}" data-delta="-1" aria-label="Decrease score">−</button>
          <button class="score-btn btn-plus" data-id="${player.id}" data-delta="1" aria-label="Increase score">+</button>
        </div>
      `;
    }).join('');
  }

  function renderPlayerScore(id, score, baseScore, delta) {
    const scoreEl = document.querySelector(`[data-score-id="${id}"]`);
    const deltaEl = document.querySelector(`[data-delta-id="${id}"]`);

    if (scoreEl) {
      scoreEl.textContent = score;
      scoreEl.classList.remove('bump');
      void scoreEl.offsetWidth;
      scoreEl.classList.add('bump');
    }

    if (deltaEl) {
      if (delta !== null && delta !== 0) {
        deltaEl.textContent = `${baseScore} ${delta >= 0 ? '+' : '−'} ${Math.abs(delta)} =`;
        deltaEl.classList.add('visible');
      } else {
        deltaEl.classList.remove('visible');
      }
    }
  }

  function renderColorPicker() {
    colorPicker.innerHTML = COLORS.map(color => `
      <button class="color-swatch" data-color="${color}" style="background-color: ${color}" aria-label="Select color"></button>
    `).join('');
  }

  function getTextColor(bgColor) {
    const hex = bgColor.replace('#', '');
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.5 ? '#000000' : '#FFFFFF';
  }

  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // Long press handling
  function startLongPress(id, delta) {
    wasLongPress = false;
    let count = 0;
    let delay = 150;

    longPressTimer = setTimeout(() => {
      wasLongPress = true;
      // Push undo at start of long press
      if (!playerDeltas[id]) {
        pushUndo();
      }
      longPressInterval = setInterval(() => {
        changeScore(id, delta, true);
        count++;
        if (count > 10 && delay > 50) {
          clearInterval(longPressInterval);
          delay = 50;
          longPressInterval = setInterval(() => changeScore(id, delta, true), delay);
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
    btnAddPlayer.addEventListener('click', addPlayer);
    btnUndo.addEventListener('click', undo);
    btnReset.addEventListener('click', resetScores);
    btnSort.addEventListener('click', toggleSort);
    btnSound.addEventListener('click', toggleSound);

    // Player list - tap on row to edit
    playerList.addEventListener('click', (e) => {
      const scoreBtn = e.target.closest('.score-btn');
      if (scoreBtn) {
        e.stopPropagation();
        return;
      }

      const row = e.target.closest('.player-row');
      if (row) {
        openEditModal(row.dataset.id, false);
      }
    });

    // Score buttons - handle both mouse and touch
    playerList.addEventListener('mousedown', handleScoreButtonDown);
    playerList.addEventListener('touchstart', handleScoreButtonDown, { passive: true });

    document.addEventListener('mouseup', handleScoreButtonUp);
    document.addEventListener('touchend', handleScoreButtonUp);
    document.addEventListener('touchcancel', handleScoreButtonCancel);

    // Edit modal
    btnDeletePlayer.addEventListener('click', () => {
      if (editingPlayerId) removePlayer(editingPlayerId);
    });

    btnConfirmEdit.addEventListener('click', confirmEdit);

    editNameInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') confirmEdit();
      if (e.key === 'Escape') closeEditModal();
    });

    colorPicker.addEventListener('click', (e) => {
      const swatch = e.target.closest('.color-swatch');
      if (swatch) selectColor(swatch.dataset.color);
    });

    editModal.addEventListener('click', (e) => {
      if (e.target === editModal) closeEditModal();
    });

    // Prevent double-tap zoom
    let lastTap = 0;
    document.addEventListener('touchend', (e) => {
      const now = Date.now();
      if (now - lastTap < 300) {
        e.preventDefault();
      }
      lastTap = now;
    }, { passive: false });
  }

  let activeButtonId = null;
  let activeButtonDelta = null;

  function handleScoreButtonDown(e) {
    const btn = e.target.closest('.score-btn');
    if (!btn) return;

    e.preventDefault(); // Prevent click event from also firing
    activeButtonId = btn.dataset.id;
    activeButtonDelta = parseInt(btn.dataset.delta, 10);
    startLongPress(activeButtonId, activeButtonDelta);
  }

  function handleScoreButtonUp(e) {
    const savedWasLongPress = wasLongPress;
    const savedId = activeButtonId;
    const savedDelta = activeButtonDelta;

    stopLongPress();

    if (!savedId) return;

    // Only trigger single increment if we didn't do a long press
    if (!savedWasLongPress) {
      changeScore(savedId, savedDelta, false);
    }

    activeButtonId = null;
    activeButtonDelta = null;
    wasLongPress = false;
  }

  function handleScoreButtonCancel() {
    stopLongPress();
    activeButtonId = null;
    activeButtonDelta = null;
    wasLongPress = false;
  }

  // Start app
  init();
})();
