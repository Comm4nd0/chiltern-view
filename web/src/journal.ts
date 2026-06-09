import type { LogEntryType } from './api/types'

/** The note types a person writes by hand (task_completed entries are system-made). */
export const NOTE_TYPES: [LogEntryType, string][] = [
  ['general', 'General'],
  ['health', 'Health'],
  ['feeding', 'Feeding'],
  ['breeding', 'Breeding'],
]

export const TYPE_COLORS: Record<string, string> = {
  general: '#00796B',
  health: '#FF3B30',
  feeding: '#FF9500',
  breeding: '#AF52DE',
  task_completed: '#8E8E93',
}
