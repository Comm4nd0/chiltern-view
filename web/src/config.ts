import { useSyncExternalStore } from 'react'

// Which Person this browser acts as ("me"). Drives the default dashboard filter
// and the default assignee on new tasks. Stored per-browser in localStorage.
const KEY = 'my_person_id'

function read(): number | null {
  const v = localStorage.getItem(KEY)
  return v ? Number(v) : null
}

let myPersonId: number | null = read()
const listeners = new Set<() => void>()

export function getMyPersonId(): number | null {
  return myPersonId
}

export function setMyPersonId(id: number | null): void {
  myPersonId = id
  if (id == null) localStorage.removeItem(KEY)
  else localStorage.setItem(KEY, String(id))
  listeners.forEach((l) => l())
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

/** Reactive accessor so any component re-renders when "me" changes. */
export function useMyPersonId(): number | null {
  return useSyncExternalStore(subscribe, getMyPersonId)
}
