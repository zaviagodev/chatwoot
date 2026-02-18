import { ref, computed, watch, onUnmounted } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

// Feature flag: Apple Intelligence-style glow effects during AI generation.
// Set to false to revert to the basic rotating border only.
const ENHANCED_GLOW_ENABLED = true;

const DEBOUNCE_DURATION_MS = 5000; // Must match backend CAPTAIN_DEBOUNCE_WINDOW
const ERROR_AUTO_RESET_MS = 5000;
const TIMER_INTERVAL_MS = 100;
const GENERATING_TIMEOUT_MS = 60_000; // Safety net: auto-reset if draft never arrives

/**
 * Composable for tracking the copilot draft generation lifecycle.
 * Provides visual feedback state (lock, animation, status text) while
 * Captain is generating a draft reply.
 *
 * State machine: idle → debouncing → generating → ready → error
 *
 * @returns {Object} Generation state and transition methods
 */
export function useCopilotGenerationState() {
  const currentChat = useMapGetter('getSelectedChat');

  // --- Core state ---
  const state = ref('idle');
  const startedAt = ref(null);
  const elapsedMs = ref(0);
  const errorMessage = ref('');
  const events = ref([]); // Phase 2 extensibility

  let debounceTimer = null;
  let elapsedTimer = null;
  let errorResetTimer = null;
  let generatingTimeoutTimer = null;

  // --- Computed ---
  const isLocked = computed(() =>
    ['debouncing', 'generating'].includes(state.value)
  );
  const showAnimation = computed(() =>
    ['debouncing', 'generating'].includes(state.value)
  );
  const elapsedDisplay = computed(() => (elapsedMs.value / 1000).toFixed(1));

  const statusText = computed(() => {
    const timer = elapsedMs.value >= 100 ? ` (${elapsedDisplay.value}s)` : '';
    switch (state.value) {
      case 'debouncing':
        return `Waiting for more messages...${timer}`;
      case 'generating':
        return `Captain is drafting a reply...${timer}`;
      case 'error':
        return errorMessage.value || 'Failed to generate reply';
      default:
        return '';
    }
  });

  // --- Timer helpers ---
  // stopElapsedTimer must be defined before startElapsedTimer (no-use-before-define)
  function stopElapsedTimer() {
    if (elapsedTimer) {
      clearInterval(elapsedTimer);
      elapsedTimer = null;
    }
  }

  function startElapsedTimer() {
    stopElapsedTimer();
    startedAt.value = Date.now();
    elapsedMs.value = 0;
    elapsedTimer = setInterval(() => {
      if (startedAt.value) {
        elapsedMs.value = Date.now() - startedAt.value;
      }
    }, TIMER_INTERVAL_MS);
  }

  function clearAllTimers() {
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }
    stopElapsedTimer();
    if (errorResetTimer) {
      clearTimeout(errorResetTimer);
      errorResetTimer = null;
    }
    if (generatingTimeoutTimer) {
      clearTimeout(generatingTimeoutTimer);
      generatingTimeoutTimer = null;
    }
  }

  // --- Phase 2 extensibility ---
  function logEvent(event, label = '') {
    events.value.push({ event, timestamp: Date.now(), label: label || event });
  }

  // --- Transitions ---
  // reset must be defined before onDraftError (no-use-before-define)
  function reset() {
    clearAllTimers();
    state.value = 'idle';
    startedAt.value = null;
    elapsedMs.value = 0;
    errorMessage.value = '';
    events.value = [];
  }

  function onIncomingMessage() {
    const chat = currentChat.value;
    if (!chat?.id) return;
    // G11: Only trigger for conversations in copilot draft mode
    if (chat.additional_attributes?.copilot_mode !== 'draft') return;
    // G4: Don't re-trigger if already tracking generation
    if (state.value === 'debouncing' || state.value === 'generating') return;

    clearAllTimers();
    events.value = [];
    logEvent('message_received', 'Message received');
    state.value = 'debouncing';
    startElapsedTimer();

    debounceTimer = setTimeout(() => {
      if (state.value === 'debouncing') {
        logEvent('debounce_complete', 'Processing started');
        state.value = 'generating';
        // Safety net: auto-reset if draft never arrives (e.g., missed WebSocket event)
        generatingTimeoutTimer = setTimeout(() => {
          if (state.value === 'generating') reset();
        }, GENERATING_TIMEOUT_MS);
      }
    }, DEBOUNCE_DURATION_MS);
  }

  function onDraftReceived() {
    // Handles both generating and debouncing (edge case: fast draft) states
    if (state.value === 'idle') return;
    logEvent('draft_ready', 'Draft ready');
    clearAllTimers();
    state.value = 'ready';
  }

  function onDraftError(message = '') {
    logEvent('error', message || 'Generation failed');
    clearAllTimers();
    errorMessage.value = message || 'Failed to generate reply';
    state.value = 'error';
    errorResetTimer = setTimeout(() => {
      if (state.value === 'error') reset();
    }, ERROR_AUTO_RESET_MS);
  }

  // --- Watchers ---
  // Conversation switch: reset state when agent changes conversation
  watch(
    () => currentChat.value?.id,
    (newId, oldId) => {
      if (newId !== oldId && state.value !== 'idle') reset();
    }
  );

  // New incoming message detection: watch messages array length
  watch(
    () => currentChat.value?.messages?.length,
    (newLen, oldLen) => {
      if (!newLen || !oldLen || newLen <= oldLen) return;
      const messages = currentChat.value?.messages || [];
      const lastMsg = messages[messages.length - 1];
      // G6: Only trigger for incoming customer messages, not private notes
      // G16: message_type === 0 filters out outgoing (1) and activity (2)
      if (lastMsg?.message_type === 0 && !lastMsg.private) {
        onIncomingMessage();
      }
    }
  );

  // NOTE: No copilotDraft watcher here — ReplyBox calls onDraftReceived()
  // explicitly in its existing copilotDraft watcher (G17: avoids double-firing).
  //
  // NOTE: Error handling is wired via BUS_EVENTS.COPILOT_DRAFT_ERROR listener
  // in ReplyBox, which calls onDraftError(). The composable does not detect
  // errors internally because setCopilotDraftError only clears the draft
  // (null -> null transition is invisible to watchers). See G12.

  // G8: Clean up all timers on unmount
  onUnmounted(() => clearAllTimers());

  return {
    // State
    state,
    startedAt,
    elapsedMs,
    errorMessage,
    events,

    // Derived
    isLocked,
    showAnimation,
    enhancedGlow: computed(() => ENHANCED_GLOW_ENABLED && showAnimation.value),
    statusText,
    elapsedDisplay,

    // Methods
    onIncomingMessage,
    onDraftReceived,
    onDraftError,
    reset,
  };
}
