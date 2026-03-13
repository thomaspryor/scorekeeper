// Scorekeeper App
(function() {
  'use strict';

  // Color palette - matches original Scorekeeper XL order
  const COLORS = [
    '#FF4136', // Red
    '#FF851B', // Orange
    '#FFDC00', // Yellow
    '#2ECC40', // Green
    '#39CCCC', // Cyan
    '#01FF70', // Lime
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
    sortMode: 'none', // 'none', 'desc', 'asc'
    originalOrder: [], // Array of player IDs in original (unsorted) order
    increment: 1
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

  // Swipe tracking
  let swipeStartX = null;
  let swipeStartY = null;
  let swipeRow = null;
  let swipeStartTime = null;
  let swipeDirection = null; // 'left' for delete, 'right' for edit

  // Drag reorder tracking
  let draggedPlayer = null;
  let dragStartY = null;

  // PWA install prompt
  let deferredInstallPrompt = null;

  // Toast container
  const toastContainer = document.getElementById('toast-container');
  let currentToast = null;
  let toastTimeout = null;

  // DOM Elements
  const playerList = document.getElementById('player-list');
  const editModal = document.getElementById('edit-modal');
  const colorPicker = document.getElementById('color-picker');
  const editNameInput = document.getElementById('edit-name');
  const btnAddPlayer = document.getElementById('btn-add-player');
  const btnUndo = document.getElementById('btn-undo');
  const btnReset = document.getElementById('btn-reset');
  const btnNewGame = document.getElementById('btn-new-game');
  const btnSort = document.getElementById('btn-sort');
  const btnSound = document.getElementById('btn-sound');
  const btnIncrement = document.getElementById('btn-increment');
  const incrementLabel = document.getElementById('increment-label');
  const btnEndGame = document.getElementById('btn-end-game');
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
    updateIncrementLabel();
  }

  // Audio - iOS Safari requires AudioContext to be created AND produce output
  // within the same user gesture call stack. We unlock it by playing a silent
  // buffer on first interaction so subsequent playSound() calls work.
  let audioUnlocked = false;

  function ensureAudio() {
    if (!audioContext) {
      audioContext = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioContext.state === 'suspended') {
      audioContext.resume();
    }
    // Play a silent buffer to unlock audio on iOS
    if (!audioUnlocked && audioContext.state === 'running') {
      const silentBuffer = audioContext.createBuffer(1, 1, 22050);
      const source = audioContext.createBufferSource();
      source.buffer = silentBuffer;
      source.connect(audioContext.destination);
      source.start(0);
      audioUnlocked = true;
    }
  }

  function initAudio() {
    // Unlock on every user gesture type
    const unlock = () => ensureAudio();
    document.addEventListener('touchstart', unlock, true);
    document.addEventListener('touchend', unlock, true);
    document.addEventListener('mousedown', unlock, true);
    document.addEventListener('click', unlock, true);
  }

  // Storage
  function loadState() {
    try {
      const saved = localStorage.getItem('scorekeeper-state');
      if (saved) {
        const parsed = JSON.parse(saved);
        state = { ...state, ...parsed };
        // Migrate old isSorted boolean to sortMode
        if (parsed.isSorted !== undefined && !parsed.sortMode) {
          state.sortMode = parsed.isSorted ? 'desc' : 'none';
          delete state.isSorted;
        }
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
      sortMode: state.sortMode
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
    state.sortMode = snapshot.sortMode || 'none';
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
    state.sortMode = 'none'; // Adding a player breaks sort
    saveState();
    render();
    updateSortButton();
    openEditModal(player.id, true); // true = new player, focus input

    // Show gesture hints after second player added (first time only)
    if (state.players.length === 2 && !localStorage.getItem('scorekeeper-hints-shown')) {
      setTimeout(showGestureHints, 500);
    }
  }

  // Remove player (instant delete with undo toast)
  function removePlayer(id, skipToast = false) {
    const player = state.players.find(p => p.id === id);
    if (!player) return;

    pushUndo();
    state.players = state.players.filter(p => p.id !== id);
    state.originalOrder = state.originalOrder.filter(pid => pid !== id);
    delete playerDeltas[id];
    saveState();
    closeEditModal();
    render();
    haptic('warning');

    if (!skipToast) {
      showToast(`Deleted ${player.name || 'player'}`, {
        showUndo: true,
        duration: 4000,
        onUndo: () => {
          undo();
          showToast('Restored');
        }
      });
    }
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

    // Apply increment multiplier (delta is +1 or -1, multiply by increment)
    const actualDelta = delta * state.increment;

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

    playerDeltas[id].delta += actualDelta;
    player.score += actualDelta;
    saveState();

    renderPlayerScore(id, player.score, playerDeltas[id].baseScore, playerDeltas[id].delta);
    playSound();
    haptic('light');

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

  // Reset all scores (instant with undo toast)
  function resetScores() {
    if (state.players.length === 0) return;
    if (state.players.every(p => p.score === 0)) return;

    pushUndo();
    state.players.forEach(p => {
      p.score = 0;
    });
    clearAllDeltas();
    saveState();
    render();
    haptic('success');

    showToast('Scores reset to 0', {
      showUndo: true,
      duration: 4000,
      onUndo: () => {
        undo();
        showToast('Scores restored');
      }
    });
  }

  // End Game — celebration screen
  function endGame() {
    if (state.players.length < 2) return;

    // Find winner(s)
    const maxScore = Math.max(...state.players.map(p => p.score));
    const sorted = [...state.players].sort((a, b) => b.score - a.score);
    const winners = sorted.filter(p => p.score === maxScore);

    const winnerColor = winners[0].color;
    const winnerTextColor = getTextColor(winnerColor);
    const winnerName = winners.length > 1
      ? winners.map(p => escapeHtml(p.name || 'Player')).join(' & ')
      : escapeHtml(winners[0].name || 'Player');

    const overlay = document.createElement('div');
    overlay.className = 'celebration-overlay';
    overlay.style.background = winnerColor;
    overlay.style.color = winnerTextColor;

    // Build standings (excluding winner row at top)
    const standingsHtml = sorted.map((p, i) => {
      const name = escapeHtml(p.name || `Player ${state.players.findIndex(pl => pl.id === p.id) + 1}`);
      const opacity = i === 0 ? 0.15 : 0.08;
      const bg = winnerTextColor === '#FFFFFF'
        ? `rgba(255,255,255,${opacity})`
        : `rgba(0,0,0,${opacity})`;
      return `<div class="celebration-standing-row" style="background:${bg}">
        <span class="standing-rank">${i + 1}.</span>
        <span class="standing-name">${name}</span>
        <span class="standing-score">${p.score}</span>
      </div>`;
    }).join('');

    overlay.innerHTML = `
      <canvas class="celebration-confetti" id="confetti-canvas"></canvas>
      <div class="celebration-content">
        <div class="celebration-trophy">🏆</div>
        <div class="celebration-winner-name">${winnerName}</div>
        <div class="celebration-label">${winners.length > 1 ? 'Tied!' : 'Wins!'}</div>
        <div class="celebration-score">${maxScore}</div>
        <div class="celebration-standings">${standingsHtml}</div>
        <div class="celebration-buttons">
          <button class="celebration-btn btn-undo-end">Undo</button>
          <button class="celebration-btn btn-rematch">Rematch</button>
          <button class="celebration-btn btn-new-game-end">New Game</button>
        </div>
      </div>
    `;

    document.getElementById('app').appendChild(overlay);

    // Start confetti
    const canvas = document.getElementById('confetti-canvas');
    startConfetti(canvas);

    // Play celebration sound
    playCelebrationSound();
    haptic('success');

    // Button handlers
    overlay.querySelector('.btn-undo-end').addEventListener('click', () => {
      overlay.remove();
    });

    overlay.querySelector('.btn-rematch').addEventListener('click', () => {
      overlay.remove();
      pushUndo();
      state.players.forEach(p => { p.score = 0; });
      clearAllDeltas();
      saveState();
      render();
      haptic('success');
    });

    overlay.querySelector('.btn-new-game-end').addEventListener('click', () => {
      overlay.remove();
      newGame();
    });
  }

  // Confetti animation
  function startConfetti(canvas) {
    const ctx = canvas.getContext('2d');
    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;

    const pieces = [];
    const colors = ['#FF4136', '#FF851B', '#FFDC00', '#2ECC40', '#0074D9', '#F012BE', '#B10DC9', '#01FF70'];

    // Create confetti pieces
    for (let i = 0; i < 80; i++) {
      pieces.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height * -1, // Start above screen
        w: Math.random() * 8 + 4,
        h: Math.random() * 6 + 3,
        color: colors[Math.floor(Math.random() * colors.length)],
        vy: Math.random() * 3 + 2,
        vx: (Math.random() - 0.5) * 2,
        rotation: Math.random() * 360,
        rotSpeed: (Math.random() - 0.5) * 10,
        opacity: 1
      });
    }

    let frame = 0;
    const maxFrames = 180; // ~3 seconds at 60fps

    function animate() {
      frame++;
      if (frame > maxFrames) return;

      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // Fade out in last 30 frames
      const fadeStart = maxFrames - 30;

      pieces.forEach(p => {
        p.y += p.vy;
        p.x += p.vx;
        p.rotation += p.rotSpeed;
        p.vy += 0.05; // gravity

        if (frame > fadeStart) {
          p.opacity = Math.max(0, 1 - (frame - fadeStart) / 30);
        }

        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.rotation * Math.PI / 180);
        ctx.globalAlpha = p.opacity;
        ctx.fillStyle = p.color;
        ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
        ctx.restore();
      });

      requestAnimationFrame(animate);
    }

    animate();
  }

  // Celebration fanfare sound
  function playCelebrationSound() {
    if (!state.soundEnabled) return;
    ensureAudio();
    if (!audioContext || audioContext.state !== 'running') return;

    try {
      const now = audioContext.currentTime;

      // Triumphant fanfare: C5, E5, G5 (hold), then C6 (big finish)
      const notes = [
        { freq: 523, start: 0, dur: 0.15 },
        { freq: 659, start: 0.12, dur: 0.15 },
        { freq: 784, start: 0.24, dur: 0.3 },
        { freq: 1047, start: 0.5, dur: 0.5 },
      ];

      notes.forEach(n => {
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();
        osc.connect(gain);
        gain.connect(audioContext.destination);
        osc.frequency.value = n.freq;
        osc.type = 'triangle';
        const t = now + n.start;
        gain.gain.setValueAtTime(0, t);
        gain.gain.linearRampToValueAtTime(0.2, t + 0.03);
        gain.gain.setValueAtTime(0.2, t + n.dur * 0.6);
        gain.gain.exponentialRampToValueAtTime(0.001, t + n.dur);
        osc.start(t);
        osc.stop(t + n.dur + 0.05);
      });

      // Add a shimmer chord on top
      [1047, 1319, 1568].forEach(freq => {
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();
        osc.connect(gain);
        gain.connect(audioContext.destination);
        osc.frequency.value = freq;
        osc.type = 'sine';
        const t = now + 0.5;
        gain.gain.setValueAtTime(0, t);
        gain.gain.linearRampToValueAtTime(0.08, t + 0.05);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.8);
        osc.start(t);
        osc.stop(t + 0.85);
      });
    } catch (e) {
      // Sound not supported
    }
  }

  // Game History
  function loadGameHistory() {
    try {
      const saved = localStorage.getItem('scorekeeper-history');
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      return [];
    }
  }

  function saveGameHistory(history) {
    try {
      localStorage.setItem('scorekeeper-history', JSON.stringify(history));
    } catch (e) {
      console.warn('Failed to save history:', e);
    }
  }

  function saveCurrentGame(name) {
    if (state.players.length === 0) return;

    const game = {
      id: generateId(),
      name: name || formatDefaultGameName(),
      date: Date.now(),
      players: JSON.parse(JSON.stringify(state.players)),
      increment: state.increment
    };

    const history = loadGameHistory();
    history.unshift(game); // newest first
    // Keep max 50 games
    if (history.length > 50) history.pop();
    saveGameHistory(history);
    return game;
  }

  function formatDefaultGameName() {
    const d = new Date();
    const month = d.toLocaleString('default', { month: 'short' });
    const day = d.getDate();
    return `Game ${month} ${day}`;
  }

  function loadGame(gameId) {
    const history = loadGameHistory();
    const game = history.find(g => g.id === gameId);
    if (!game) return;

    pushUndo();
    state.players = JSON.parse(JSON.stringify(game.players));
    state.originalOrder = state.players.map(p => p.id);
    state.sortMode = 'none';
    if (game.increment) state.increment = game.increment;
    clearAllDeltas();
    saveState();
    render();
    updateSortButton();
    updateUndoButton();
    updateIncrementLabel();
    haptic('success');
    showToast(`Loaded "${game.name}"`);
  }

  function deleteGame(gameId) {
    const history = loadGameHistory();
    const game = history.find(g => g.id === gameId);
    const filtered = history.filter(g => g.id !== gameId);
    saveGameHistory(filtered);
    if (game) {
      showToast(`Deleted "${game.name}"`);
    }
  }

  // New Game flow — show save dialog if there are players
  function newGame() {
    if (state.players.length === 0) {
      showPastGames();
      return;
    }
    showNewGameDialog();
  }

  function showNewGameDialog() {
    const overlay = document.createElement('div');
    overlay.className = 'game-dialog-overlay';

    const playerSummary = state.players
      .sort((a, b) => b.score - a.score)
      .map(p => `${p.name || 'Player'} ${p.score}`)
      .join(' · ');

    overlay.innerHTML = `
      <div class="game-dialog">
        <h2>Save this game?</h2>
        <div class="game-dialog-summary">${escapeHtml(playerSummary)}</div>
        <input type="text" class="game-dialog-input" placeholder="Game name (optional)" maxlength="40" autocomplete="off" autocorrect="off" spellcheck="false">
        <div class="game-dialog-buttons">
          <button class="game-dialog-btn save-btn">Save & New Game</button>
          <button class="game-dialog-btn discard-btn">Don't Save</button>
        </div>
        <button class="game-dialog-past-link">View Past Games</button>
      </div>
    `;

    const input = overlay.querySelector('.game-dialog-input');
    const saveBtn = overlay.querySelector('.save-btn');
    const discardBtn = overlay.querySelector('.discard-btn');
    const pastLink = overlay.querySelector('.game-dialog-past-link');

    saveBtn.addEventListener('click', () => {
      const game = saveCurrentGame(input.value.trim());
      overlay.remove();
      clearCurrentGame();
      showToast(`Saved "${game.name}"`);
    });

    discardBtn.addEventListener('click', () => {
      overlay.remove();
      clearCurrentGame();
    });

    pastLink.addEventListener('click', () => {
      overlay.remove();
      showPastGames();
    });

    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') saveBtn.click();
    });

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) overlay.remove();
    });

    document.getElementById('app').appendChild(overlay);
    setTimeout(() => input.focus(), 100);
  }

  function clearCurrentGame() {
    pushUndo();
    state.players = [];
    state.originalOrder = [];
    state.sortMode = 'none';
    state.increment = 1;
    clearAllDeltas();
    saveState();
    render();
    updateSortButton();
    updateUndoButton();
    updateIncrementLabel();
    haptic('success');
  }

  // Past Games view
  function showPastGames() {
    const history = loadGameHistory();

    const overlay = document.createElement('div');
    overlay.className = 'game-dialog-overlay';

    if (history.length === 0) {
      overlay.innerHTML = `
        <div class="game-dialog past-games-dialog">
          <div class="past-games-header">
            <h2>Past Games</h2>
            <button class="past-games-close">✕</button>
          </div>
          <div class="past-games-empty">No saved games yet.<br>Games are saved when you start a new one.</div>
        </div>
      `;
    } else {
      overlay.innerHTML = `
        <div class="game-dialog past-games-dialog">
          <div class="past-games-header">
            <h2>Past Games</h2>
            <button class="past-games-close">✕</button>
          </div>
          <div class="past-games-list">
            ${history.map(game => {
              const date = new Date(game.date);
              const dateStr = date.toLocaleDateString('default', { month: 'short', day: 'numeric' });
              const players = game.players
                .sort((a, b) => b.score - a.score)
                .map(p => `<span style="color:${game.players.length <= 6 ? p.color : 'inherit'}">${escapeHtml(p.name || 'Player')} ${p.score}</span>`)
                .join(', ');
              return `
                <div class="past-game-item" data-game-id="${game.id}">
                  <div class="past-game-info">
                    <div class="past-game-name">${escapeHtml(game.name)}</div>
                    <div class="past-game-meta">${dateStr} · ${players}</div>
                  </div>
                  <button class="past-game-menu-btn" data-game-id="${game.id}">···</button>
                </div>
              `;
            }).join('')}
          </div>
        </div>
      `;
    }

    // Close button
    overlay.querySelector('.past-games-close').addEventListener('click', () => overlay.remove());

    // Click outside to close
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) overlay.remove();
    });

    // Handle game item clicks (load) and menu clicks
    overlay.addEventListener('click', (e) => {
      const menuBtn = e.target.closest('.past-game-menu-btn');
      if (menuBtn) {
        e.stopPropagation();
        showGameMenu(menuBtn.dataset.gameId, menuBtn, overlay);
        return;
      }

      const item = e.target.closest('.past-game-item');
      if (item) {
        const gameId = item.dataset.gameId;
        overlay.remove();
        loadGame(gameId);
      }
    });

    document.getElementById('app').appendChild(overlay);
  }

  function showGameMenu(gameId, anchor, parentOverlay) {
    // Remove any existing menu
    const existing = document.querySelector('.past-game-popup-menu');
    if (existing) { existing.remove(); return; }

    const menu = document.createElement('div');
    menu.className = 'past-game-popup-menu';
    menu.innerHTML = `
      <button class="popup-menu-item" data-action="load">Load Game</button>
      <button class="popup-menu-item delete" data-action="delete">Delete</button>
    `;

    menu.addEventListener('click', (e) => {
      const action = e.target.dataset.action;
      if (action === 'load') {
        parentOverlay.remove();
        loadGame(gameId);
      } else if (action === 'delete') {
        deleteGame(gameId);
        parentOverlay.remove();
        showPastGames(); // Re-render
      }
      menu.remove();
    });

    // Position near the anchor
    const rect = anchor.getBoundingClientRect();
    menu.style.position = 'fixed';
    menu.style.top = `${rect.bottom + 4}px`;
    menu.style.right = `${window.innerWidth - rect.right}px`;

    document.getElementById('app').appendChild(menu);

    // Close on outside click
    setTimeout(() => {
      const closeMenu = (e) => {
        if (!menu.contains(e.target)) {
          menu.remove();
          document.removeEventListener('click', closeMenu);
        }
      };
      document.addEventListener('click', closeMenu);
    }, 0);
  }

  // Sort/Unsort players
  function toggleSort() {
    if (state.players.length < 2) return;

    pushUndo();

    if (state.sortMode === 'none') {
      // Sort high to low
      state.players.sort((a, b) => b.score - a.score);
      state.sortMode = 'desc';
    } else if (state.sortMode === 'desc') {
      // Sort low to high
      state.players.sort((a, b) => a.score - b.score);
      state.sortMode = 'asc';
    } else {
      // Unsort - restore original order
      const playerMap = new Map(state.players.map(p => [p.id, p]));
      state.players = state.originalOrder
        .filter(id => playerMap.has(id))
        .map(id => playerMap.get(id));
      state.sortMode = 'none';
    }

    saveState();
    render();
    updateSortButton();

    // Play ta-dah sound and animate after render
    playSortSound();
    animateSort();
    haptic('success');
  }

  // Animate sort with staggered slide-in
  function animateSort() {
    // After render, animate each row
    requestAnimationFrame(() => {
      const rows = playerList.querySelectorAll('.player-row');
      rows.forEach((row, i) => {
        row.style.opacity = '0';
        row.style.transform = 'translateX(-30px)';
        row.style.transition = 'none';

        requestAnimationFrame(() => {
          row.style.transition = `opacity 0.3s ease ${i * 0.05}s, transform 0.3s ease ${i * 0.05}s`;
          row.style.opacity = '1';
          row.style.transform = 'translateX(0)';
        });
      });
    });
  }

  function updateSortButton() {
    const label = btnSort.querySelector('.sort-label');
    if (label) {
      const labels = { none: 'Sort', desc: 'Sort ↑', asc: 'Unsort' };
      label.textContent = labels[state.sortMode];
    }
  }

  // Sound
  function playSound() {
    if (!state.soundEnabled) return;
    ensureAudio();
    if (!audioContext || audioContext.state !== 'running') return;

    try {
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      oscillator.connect(gain);
      gain.connect(audioContext.destination);
      oscillator.frequency.value = 880;
      oscillator.type = 'sine';
      gain.gain.setValueAtTime(0.3, audioContext.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + 0.12);
      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 0.12);
    } catch (e) {
      // Sound not supported
    }
  }

  // Ta-dah sound for sort
  function playSortSound() {
    if (!state.soundEnabled) return;
    ensureAudio();
    if (!audioContext || audioContext.state !== 'running') return;

    try {
      const now = audioContext.currentTime;

      // Rising arpeggio: C5, E5, G5, C6
      const notes = [523, 659, 784, 1047];
      notes.forEach((freq, i) => {
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();
        osc.connect(gain);
        gain.connect(audioContext.destination);
        osc.frequency.value = freq;
        osc.type = 'sine';
        const startTime = now + i * 0.08;
        gain.gain.setValueAtTime(0, startTime);
        gain.gain.linearRampToValueAtTime(0.15, startTime + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.2);
        osc.start(startTime);
        osc.stop(startTime + 0.25);
      });
    } catch (e) {
      // Sound not supported
    }
  }

  function toggleSound() {
    state.soundEnabled = !state.soundEnabled;
    saveState();
    updateSoundButton();
    if (state.soundEnabled) {
      ensureAudio();
      playSound();
    }
  }

  // Haptic feedback
  function haptic(style = 'light') {
    if (!navigator.vibrate) return;
    try {
      switch (style) {
        case 'light':
          navigator.vibrate(10);
          break;
        case 'medium':
          navigator.vibrate(20);
          break;
        case 'heavy':
          navigator.vibrate(30);
          break;
        case 'success':
          navigator.vibrate([10, 50, 20]);
          break;
        case 'warning':
          navigator.vibrate([20, 30, 20, 30, 20]);
          break;
      }
    } catch (e) {
      // Haptics not supported
    }
  }

  function updateSoundButton() {
    btnSound.classList.toggle('sound-off', !state.soundEnabled);
  }

  function updateIncrementLabel() {
    if (incrementLabel) {
      incrementLabel.textContent = `±${state.increment}`;
    }
  }

  // Toast notifications
  function showToast(message, options = {}) {
    const { showUndo = false, duration = 3000, onUndo = null } = options;

    // Clear existing toast
    if (currentToast) {
      currentToast.remove();
      clearTimeout(toastTimeout);
    }

    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerHTML = `
      <span>${escapeHtml(message)}</span>
      ${showUndo ? '<button class="toast-undo-btn">Undo</button>' : ''}
    `;

    if (showUndo && onUndo) {
      toast.querySelector('.toast-undo-btn').addEventListener('click', () => {
        onUndo();
        hideToast(toast);
      });
    }

    toastContainer.appendChild(toast);
    currentToast = toast;

    toastTimeout = setTimeout(() => hideToast(toast), duration);

    return toast;
  }

  function hideToast(toast) {
    if (!toast || !toast.parentNode) return;
    toast.classList.add('hiding');
    setTimeout(() => {
      if (toast.parentNode) toast.remove();
      if (currentToast === toast) currentToast = null;
    }, 200);
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
        <button class="empty-state-btn" id="empty-state-add">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M15 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm-9-2V7H4v3H1v2h3v3h2v-3h3v-2H6zm9 4c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
          </svg>
          <span>Tap to Add Your First Player</span>
        </button>
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
        <div class="player-row-wrapper" data-id="${player.id}">
          <div class="swipe-edit-bg" data-swipe-edit="${player.id}">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/></svg>
          </div>
          <div class="player-row" data-id="${player.id}" style="background-color: ${player.color}; color: ${getTextColor(player.color)}">
            <div class="drag-handle" data-drag="${player.id}" aria-label="Drag to reorder">
              <svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 18c0 1.1-.9 2-2 2s-2-.9-2-2 .9-2 2-2 2 .9 2 2zm-2-8c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0-6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm6 4c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"/></svg>
            </div>
            <span class="player-name">${escapeHtml(displayName)}</span>
            <div class="score-display">
              <span class="score-delta ${showDelta ? 'visible' : ''}" data-delta-id="${player.id}">${deltaText}</span>
              <span class="player-score" data-score-id="${player.id}">${player.score}</span>
            </div>
            <button class="score-btn btn-minus" data-id="${player.id}" data-delta="-1" aria-label="Decrease score">−${state.increment > 1 ? `<span class="increment-label">${state.increment}</span>` : ''}</button>
            <button class="score-btn btn-plus" data-id="${player.id}" data-delta="1" aria-label="Increase score">+${state.increment > 1 ? `<span class="increment-label">${state.increment}</span>` : ''}</button>
          </div>
          <div class="swipe-delete-bg" data-swipe-delete="${player.id}">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>
          </div>
        </div>
      `;
    }).join('') + `
      <button class="add-player-btn" id="add-player-below">
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M15 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm-9-2V7H4v3H1v2h3v3h2v-3h3v-2H6zm9 4c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
        </svg>
        <span>Add Player</span>
      </button>
    `;
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
    btnEndGame.addEventListener('click', endGame);
    btnReset.addEventListener('click', resetScores);
    btnNewGame.addEventListener('click', newGame);
    btnSort.addEventListener('click', toggleSort);
    btnSound.addEventListener('click', toggleSound);
    btnIncrement.addEventListener('click', showIncrementPicker);

    // Player list - handle clicks (edit via swipe, not tap)
    playerList.addEventListener('click', (e) => {
      // Handle empty state button
      const emptyBtn = e.target.closest('.empty-state-btn');
      if (emptyBtn) {
        addPlayer();
        return;
      }

      // Handle add player button below list
      const addBelowBtn = e.target.closest('.add-player-btn');
      if (addBelowBtn) {
        addPlayer();
        return;
      }

      const scoreBtn = e.target.closest('.score-btn');
      if (scoreBtn) {
        e.stopPropagation();
        return;
      }

      const dragHandle = e.target.closest('.drag-handle');
      if (dragHandle) {
        e.stopPropagation();
        return;
      }
    });

    // Score buttons - handle both mouse and touch
    playerList.addEventListener('mousedown', handleScoreButtonDown);
    playerList.addEventListener('touchstart', handleScoreButtonDown, { passive: false });

    // Swipe to delete
    playerList.addEventListener('touchstart', handleSwipeStart, { passive: true });
    playerList.addEventListener('touchmove', handleSwipeMove, { passive: true });
    playerList.addEventListener('touchend', handleSwipeEnd, { passive: true });

    // Drag to reorder
    playerList.addEventListener('touchstart', handleDragStart, { passive: false });
    playerList.addEventListener('touchmove', handleDragMove, { passive: false });
    playerList.addEventListener('touchend', handleDragEnd, { passive: true });
    playerList.addEventListener('mousedown', handleDragStart);
    document.addEventListener('mousemove', handleDragMove);
    document.addEventListener('mouseup', handleDragEnd);

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

  // Swipe to delete (left) or edit (right)
  // iOS edge protection: ignore swipes starting within 25px of screen edges
  const EDGE_THRESHOLD = 25;

  function handleSwipeStart(e) {
    const row = e.target.closest('.player-row');
    if (!row || e.target.closest('.score-btn') || e.target.closest('.drag-handle')) return;

    const touch = e.touches ? e.touches[0] : e;

    // Prevent conflict with iOS back/forward swipe gestures
    if (touch.clientX < EDGE_THRESHOLD || touch.clientX > window.innerWidth - EDGE_THRESHOLD) {
      return;
    }

    swipeStartX = touch.clientX;
    swipeStartY = touch.clientY;
    swipeRow = row.closest('.player-row-wrapper');
    swipeStartTime = Date.now();
    swipeDirection = null;
  }

  function handleSwipeMove(e) {
    if (!swipeRow || swipeStartX === null) return;

    const touch = e.touches ? e.touches[0] : e;
    const deltaX = touch.clientX - swipeStartX;
    const deltaY = touch.clientY - swipeStartY;

    // If more vertical than horizontal, cancel swipe
    if (Math.abs(deltaY) > Math.abs(deltaX) && Math.abs(deltaY) > 10) {
      snapBackRow();
      resetSwipe();
      return;
    }

    // Determine swipe direction once we have enough movement
    if (swipeDirection === null && Math.abs(deltaX) > 10) {
      swipeDirection = deltaX > 0 ? 'right' : 'left';
    }

    const playerRow = swipeRow.querySelector('.player-row');
    if (playerRow) {
      if (swipeDirection === 'left') {
        // Left swipe for delete - limit to -120px
        const swipeAmount = Math.max(deltaX, -120);
        playerRow.style.transform = `translateX(${swipeAmount}px)`;
      } else if (swipeDirection === 'right') {
        // Right swipe for edit - limit to 120px
        const swipeAmount = Math.min(deltaX, 120);
        playerRow.style.transform = `translateX(${swipeAmount}px)`;
      }
      playerRow.style.transition = 'none';
    }
  }

  function handleSwipeEnd(e) {
    if (!swipeRow || swipeStartX === null) return;

    const playerRow = swipeRow.querySelector('.player-row');
    if (!playerRow) {
      resetSwipe();
      return;
    }

    const touch = e.changedTouches ? e.changedTouches[0] : e;
    const deltaX = touch.clientX - swipeStartX;
    const velocity = Math.abs(deltaX) / (Date.now() - swipeStartTime);
    const playerId = swipeRow.dataset.id;

    // Left swipe - delete (instant with undo toast)
    if (swipeDirection === 'left' && (deltaX < -80 || (deltaX < -40 && velocity > 0.5))) {
      playerRow.style.transition = 'transform 0.2s ease-out';
      playerRow.style.transform = 'translateX(-100%)';

      const player = state.players.find(p => p.id === playerId);
      const playerName = player ? (player.name || 'player') : 'player';

      setTimeout(() => {
        pushUndo();
        state.players = state.players.filter(p => p.id !== playerId);
        state.originalOrder = state.originalOrder.filter(pid => pid !== playerId);
        delete playerDeltas[playerId];
        saveState();
        render();
        haptic('warning');

        showToast(`Deleted ${playerName}`, {
          showUndo: true,
          duration: 4000,
          onUndo: () => {
            undo();
            showToast('Restored');
          }
        });
      }, 200);
    }
    // Right swipe - edit
    else if (swipeDirection === 'right' && (deltaX > 80 || (deltaX > 40 && velocity > 0.5))) {
      playerRow.style.transition = 'transform 0.2s ease-out';
      playerRow.style.transform = 'translateX(0)';
      haptic('medium');
      openEditModal(playerId, false);
    }
    // Not enough to trigger action - snap back
    else {
      playerRow.style.transition = 'transform 0.2s ease-out';
      playerRow.style.transform = 'translateX(0)';
    }

    resetSwipe();
  }

  function snapBackRow() {
    if (swipeRow) {
      const playerRow = swipeRow.querySelector('.player-row');
      if (playerRow) {
        playerRow.style.transition = 'transform 0.2s ease-out';
        playerRow.style.transform = 'translateX(0)';
      }
    }
  }

  function resetSwipe() {
    swipeStartX = null;
    swipeStartY = null;
    swipeRow = null;
    swipeStartTime = null;
    swipeDirection = null;
  }

  // Drag to reorder
  function handleDragStart(e) {
    const handle = e.target.closest('.drag-handle');
    if (!handle) return;

    e.preventDefault();
    const playerId = handle.dataset.drag;
    const wrapper = handle.closest('.player-row-wrapper');
    if (!wrapper) return;

    draggedPlayer = playerId;
    const touch = e.touches ? e.touches[0] : e;
    dragStartY = touch.clientY;

    wrapper.classList.add('dragging');
    haptic('medium');

    // Store original positions
    const wrappers = playerList.querySelectorAll('.player-row-wrapper');
    wrappers.forEach(w => {
      const rect = w.getBoundingClientRect();
      w.dataset.originalTop = rect.top;
    });
  }

  function handleDragMove(e) {
    if (!draggedPlayer) return;

    e.preventDefault();
    const touch = e.touches ? e.touches[0] : e;
    const currentY = touch.clientY;
    const deltaY = currentY - dragStartY;

    const draggedWrapper = playerList.querySelector(`.player-row-wrapper[data-id="${draggedPlayer}"]`);
    if (!draggedWrapper) return;

    draggedWrapper.style.transform = `translateY(${deltaY}px)`;
    draggedWrapper.style.zIndex = '100';

    // Find which position we're over
    const wrappers = Array.from(playerList.querySelectorAll('.player-row-wrapper'));
    const draggedIndex = wrappers.findIndex(w => w.dataset.id === draggedPlayer);
    const draggedRect = draggedWrapper.getBoundingClientRect();
    const draggedCenter = draggedRect.top + draggedRect.height / 2;

    wrappers.forEach((wrapper, i) => {
      if (wrapper.dataset.id === draggedPlayer) return;

      const rect = wrapper.getBoundingClientRect();
      const center = rect.top + rect.height / 2;

      if (i < draggedIndex && draggedCenter < center + rect.height / 2) {
        wrapper.style.transform = `translateY(${draggedRect.height}px)`;
      } else if (i > draggedIndex && draggedCenter > center - rect.height / 2) {
        wrapper.style.transform = `translateY(-${draggedRect.height}px)`;
      } else {
        wrapper.style.transform = '';
      }
      wrapper.style.transition = 'transform 0.15s ease-out';
    });
  }

  function handleDragEnd(e) {
    if (!draggedPlayer) return;

    const draggedWrapper = playerList.querySelector(`.player-row-wrapper[data-id="${draggedPlayer}"]`);
    if (!draggedWrapper) {
      resetDrag();
      return;
    }

    const draggedRect = draggedWrapper.getBoundingClientRect();
    const draggedCenter = draggedRect.top + draggedRect.height / 2;

    // Calculate new position
    const wrappers = Array.from(playerList.querySelectorAll('.player-row-wrapper'));
    const draggedIndex = state.players.findIndex(p => p.id === draggedPlayer);
    let newIndex = draggedIndex;

    wrappers.forEach((wrapper, i) => {
      if (wrapper.dataset.id === draggedPlayer) return;
      const rect = wrapper.getBoundingClientRect();
      const center = parseFloat(wrapper.dataset.originalTop) + rect.height / 2;

      if (draggedCenter < center && i < newIndex) {
        newIndex = i;
      } else if (draggedCenter > center && i >= newIndex) {
        newIndex = i;
      }
    });

    // Move player in array
    if (newIndex !== draggedIndex) {
      pushUndo();
      const [player] = state.players.splice(draggedIndex, 1);
      state.players.splice(newIndex, 0, player);

      // Update original order for unsort
      const [orderId] = state.originalOrder.splice(
        state.originalOrder.indexOf(draggedPlayer), 1
      );
      const targetId = state.players[newIndex === 0 ? 0 : newIndex - 1]?.id;
      const targetOriginalIndex = targetId ? state.originalOrder.indexOf(targetId) : -1;
      state.originalOrder.splice(
        newIndex === 0 ? 0 : targetOriginalIndex + 1, 0, orderId
      );

      state.sortMode = 'none';
      saveState();
      haptic('success');
    }

    render();
    updateSortButton();
    resetDrag();
  }

  function resetDrag() {
    const wrappers = playerList.querySelectorAll('.player-row-wrapper');
    wrappers.forEach(w => {
      w.classList.remove('dragging');
      w.style.transform = '';
      w.style.zIndex = '';
      w.style.transition = '';
    });
    draggedPlayer = null;
    dragStartY = null;
  }

  // Shake to undo
  let lastShakeTime = 0;
  let shakeThreshold = 15; // Acceleration threshold
  let lastX = null, lastY = null, lastZ = null;

  function initShakeDetection() {
    if (!window.DeviceMotionEvent) return;

    // iOS 13+ requires permission
    if (typeof DeviceMotionEvent.requestPermission === 'function') {
      // Will request on first user interaction
      document.addEventListener('touchstart', requestMotionPermission, { once: true });
    } else {
      window.addEventListener('devicemotion', handleDeviceMotion);
    }
  }

  function requestMotionPermission() {
    DeviceMotionEvent.requestPermission()
      .then(response => {
        if (response === 'granted') {
          window.addEventListener('devicemotion', handleDeviceMotion);
        }
      })
      .catch(console.warn);
  }

  function handleDeviceMotion(e) {
    const acc = e.accelerationIncludingGravity;
    if (!acc) return;

    const { x, y, z } = acc;

    if (lastX !== null) {
      const deltaX = Math.abs(x - lastX);
      const deltaY = Math.abs(y - lastY);
      const deltaZ = Math.abs(z - lastZ);
      const totalDelta = deltaX + deltaY + deltaZ;

      if (totalDelta > shakeThreshold) {
        const now = Date.now();
        if (now - lastShakeTime > 1000) { // Debounce: 1 second between shakes
          lastShakeTime = now;
          handleShake();
        }
      }
    }

    lastX = x;
    lastY = y;
    lastZ = z;
  }

  function handleShake() {
    if (undoStack.length > 0) {
      haptic('medium');
      undo();
      showToast('Shake undo!');
    }
  }

  // PWA install prompt
  function initPWA() {
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      deferredInstallPrompt = e;
      showInstallBanner();
    });
  }

  function showInstallBanner() {
    if (!deferredInstallPrompt) return;

    // Only show if not already installed and user hasn't dismissed
    if (localStorage.getItem('pwa-install-dismissed')) return;

    const banner = document.createElement('div');
    banner.className = 'install-banner';
    banner.innerHTML = `
      <span>Install Scorekeeper for quick access!</span>
      <button class="install-btn">Install</button>
      <button class="install-dismiss">✕</button>
    `;

    banner.querySelector('.install-btn').addEventListener('click', async () => {
      if (deferredInstallPrompt) {
        deferredInstallPrompt.prompt();
        const { outcome } = await deferredInstallPrompt.userChoice;
        if (outcome === 'accepted') {
          haptic('success');
        }
        deferredInstallPrompt = null;
      }
      banner.remove();
    });

    banner.querySelector('.install-dismiss').addEventListener('click', () => {
      localStorage.setItem('pwa-install-dismissed', 'true');
      banner.remove();
    });

    document.body.appendChild(banner);
  }

  // Increment picker
  const INCREMENT_OPTIONS = [1, 2, 5, 10, 25, 50, 100];
  let incrementPickerEl = null;

  function showIncrementPicker() {
    if (incrementPickerEl) {
      closeIncrementPicker();
      return;
    }

    incrementPickerEl = document.createElement('div');
    incrementPickerEl.className = 'increment-picker';
    incrementPickerEl.innerHTML = `
      <div class="increment-picker-label">Score Increment</div>
      <div class="increment-options">
        ${INCREMENT_OPTIONS.map(n => `
          <button class="increment-option ${state.increment === n ? 'selected' : ''}" data-increment="${n}">${n}</button>
        `).join('')}
      </div>
    `;

    incrementPickerEl.addEventListener('click', (e) => {
      const opt = e.target.closest('.increment-option');
      if (opt) {
        state.increment = parseInt(opt.dataset.increment, 10);
        saveState();
        render();
        updateIncrementLabel();
        closeIncrementPicker();
        haptic('light');
      }
    });

    document.getElementById('app').appendChild(incrementPickerEl);

    // Close on outside tap
    setTimeout(() => {
      document.addEventListener('click', handleIncrementOutsideClick);
    }, 0);
  }

  function handleIncrementOutsideClick(e) {
    if (incrementPickerEl && !incrementPickerEl.contains(e.target) && !e.target.closest('#btn-increment')) {
      closeIncrementPicker();
    }
  }

  function closeIncrementPicker() {
    if (incrementPickerEl) {
      incrementPickerEl.remove();
      incrementPickerEl = null;
      document.removeEventListener('click', handleIncrementOutsideClick);
    }
  }

  // Gesture hints (first-run onboarding)
  function showGestureHints() {
    if (localStorage.getItem('scorekeeper-hints-shown')) return;

    const overlay = document.createElement('div');
    overlay.className = 'gesture-hints-overlay';
    overlay.innerHTML = `
      <h2>Quick Tips</h2>
      <div class="gesture-hint">
        <div class="gesture-hint-icon" style="background:#0074D9">→</div>
        <div class="gesture-hint-text">
          <strong>Swipe Right</strong>
          Edit player name & color
        </div>
      </div>
      <div class="gesture-hint">
        <div class="gesture-hint-icon" style="background:#dc3545">←</div>
        <div class="gesture-hint-text">
          <strong>Swipe Left</strong>
          Delete a player
        </div>
      </div>
      <div class="gesture-hint">
        <div class="gesture-hint-icon" style="background:#555">⋮⋮</div>
        <div class="gesture-hint-text">
          <strong>Drag Handle</strong>
          Hold & drag to reorder
        </div>
      </div>
      <div class="gesture-hint">
        <div class="gesture-hint-icon" style="background:#555">📳</div>
        <div class="gesture-hint-text">
          <strong>Shake Phone</strong>
          Undo last action
        </div>
      </div>
      <div class="gesture-hint">
        <div class="gesture-hint-icon" style="background:#555">⏱</div>
        <div class="gesture-hint-text">
          <strong>Hold +/−</strong>
          Rapid score change
        </div>
      </div>
      <button class="gesture-hints-dismiss">Got it</button>
    `;

    overlay.querySelector('.gesture-hints-dismiss').addEventListener('click', () => {
      overlay.style.animation = 'none';
      overlay.style.opacity = '0';
      overlay.style.transition = 'opacity 0.2s';
      setTimeout(() => overlay.remove(), 200);
      localStorage.setItem('scorekeeper-hints-shown', 'true');
    });

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) {
        overlay.querySelector('.gesture-hints-dismiss').click();
      }
    });

    document.body.appendChild(overlay);
  }

  // Start app
  init();
  initPWA();
  initShakeDetection();
})();
