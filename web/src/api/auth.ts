import { useSyncExternalStore } from 'react'
import type { AuthUser } from './types'

// Auth token + the signed-in user, persisted per-browser in localStorage.
// Mirrors the useSyncExternalStore pattern in ../config.ts so any component can
// react to login/logout.
const TOKEN_KEY = 'auth_token'
const USER_KEY = 'auth_user'

function readUser(): AuthUser | null {
  const raw = localStorage.getItem(USER_KEY)
  if (!raw) return null
  try {
    return JSON.parse(raw) as AuthUser
  } catch {
    return null
  }
}

let token: string | null = localStorage.getItem(TOKEN_KEY)
let user: AuthUser | null = readUser()
const listeners = new Set<() => void>()

function emit() {
  listeners.forEach((l) => l())
}

// --- Sign-in prompt -------------------------------------------------------
// Read-only mode shows the whole app signed-out; a write (or the user tapping
// "Sign in") opens the login dialog via this little store.
let promptOpen = false
const promptListeners = new Set<() => void>()

function emitPrompt() {
  promptListeners.forEach((l) => l())
}

export function requireLogin(): void {
  if (!promptOpen) {
    promptOpen = true
    emitPrompt()
  }
}

export function dismissLogin(): void {
  if (promptOpen) {
    promptOpen = false
    emitPrompt()
  }
}

/** Reactive flag: whether the sign-in dialog should be shown. */
export function useLoginPrompt(): boolean {
  return useSyncExternalStore(
    (l) => {
      promptListeners.add(l)
      return () => promptListeners.delete(l)
    },
    () => promptOpen,
  )
}

export function getToken(): string | null {
  return token
}

export function getAuthUser(): AuthUser | null {
  return user
}

export function setAuth(newToken: string, newUser: AuthUser): void {
  token = newToken
  user = newUser
  localStorage.setItem(TOKEN_KEY, newToken)
  localStorage.setItem(USER_KEY, JSON.stringify(newUser))
  dismissLogin() // signed in now — close any open prompt
  emit()
}

export function clearAuth(): void {
  if (token === null && user === null) return
  token = null
  user = null
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
  emit()
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

// useSyncExternalStore needs a stable snapshot reference between changes, so we
// only rebuild the object when token/user actually change.
let snapshot: { token: string | null; user: AuthUser | null } = { token, user }
function getSnapshot() {
  if (snapshot.token !== token || snapshot.user !== user) {
    snapshot = { token, user }
  }
  return snapshot
}

/** Reactive auth state; components re-render on sign-in / sign-out. */
export function useAuth(): { token: string | null; user: AuthUser | null } {
  return useSyncExternalStore(subscribe, getSnapshot)
}
