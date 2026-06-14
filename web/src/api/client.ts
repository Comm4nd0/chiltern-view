import type {
  Animal,
  AuthUser,
  CareTask,
  Crop,
  CropCatalogEntry,
  EggRecord,
  EggSummary,
  LogEntry,
  Overview,
  Paged,
  Person,
} from './types'
import { clearAuth, getToken } from './auth'
import { queryClient } from '../queryClient'

// Same-origin in production (nginx proxies /api to the backend); the Vite dev
// server proxies /api too. Override with VITE_API_BASE if ever needed.
const BASE = import.meta.env.VITE_API_BASE ?? '/api'

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const { headers: optHeaders, ...rest } = options ?? {}
  const token = getToken()
  const res = await fetch(`${BASE}${path}`, {
    ...rest,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Token ${token}` } : {}),
      ...optHeaders,
    },
  })
  if (res.status === 401) {
    // Token missing, expired, or revoked: drop it so the app falls back to login.
    clearAuth()
    queryClient.clear()
    throw new Error('Unauthorized')
  }
  if (!res.ok) {
    const body = await res.text()
    throw new Error(`API ${res.status}: ${body}`)
  }
  if (res.status === 204) return undefined as T
  return (await res.json()) as T
}

// DRF list endpoints are paginated ({ results: [...] }); custom actions are not.
function decodeList<T>(data: unknown): T[] {
  if (data && typeof data === 'object' && 'results' in data) {
    return (data as { results: T[] }).results
  }
  return data as T[]
}

export interface CreateTaskInput {
  name: string
  recurrence_interval_days?: number
  times_per_day?: number
  due_date?: string | null
  /** Clock time "HH:MM" the task is due / its reminder fires; null = anytime that day. */
  due_time?: string | null
  description?: string
  animal?: number | null
  assignee?: number | null
}

export type UpdateTaskInput = Partial<CreateTaskInput> & { active?: boolean }

export interface CreateCropInput {
  crop: string
  variety?: string
  planted_on: string
  bed?: string
  quantity?: number | null
  expected_harvest?: string | null
  notes?: string
}

export type UpdateCropInput = Partial<CreateCropInput> & { harvested_on?: string | null }

export interface LogEntryInput {
  entry_type: string
  note: string
  animal?: number | null
  occurred_on?: string
}

export interface HarvestCropInput {
  date?: string
  yield_kg?: string
  note?: string
}

export const api = {
  login: (username: string, password: string) =>
    request<{ token: string; user: AuthUser }>('/auth/login/', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    }),
  logout: () => request<void>('/auth/logout/', { method: 'POST' }),
  me: () => request<AuthUser>('/auth/me/'),

  overview: () => request<Overview>('/overview/'),
  dashboard: (assignee?: string) =>
    request<unknown>(
      `/care-tasks/dashboard/${assignee ? `?assignee=${encodeURIComponent(assignee)}` : ''}`,
    ).then(decodeList<CareTask>),
  // One animal's tasks, including its species' shared routine (flock jobs).
  animalTasks: (animalId: number) =>
    request<unknown>(`/care-tasks/dashboard/?animal=${animalId}`).then(decodeList<CareTask>),
  completeTask: (id: number, note?: string) =>
    request<CareTask>(`/care-tasks/${id}/complete/`, {
      method: 'POST',
      body: JSON.stringify(note ? { note } : {}),
    }),
  // Undo an accidental "Done": restores the task's prior schedule.
  uncompleteTask: (id: number) =>
    request<CareTask>(`/care-tasks/${id}/uncomplete/`, { method: 'POST', body: '{}' }),
  createTask: (input: CreateTaskInput) =>
    request<CareTask>('/care-tasks/', { method: 'POST', body: JSON.stringify(input) }),
  updateTask: (id: number, patch: UpdateTaskInput) =>
    request<CareTask>(`/care-tasks/${id}/`, { method: 'PATCH', body: JSON.stringify(patch) }),
  deleteTask: (id: number) => request<void>(`/care-tasks/${id}/`, { method: 'DELETE' }),

  people: () => request<unknown>('/people/?ordering=name').then(decodeList<Person>),
  createPerson: (name: string) =>
    request<Person>('/people/', { method: 'POST', body: JSON.stringify({ name }) }),
  deletePerson: (id: number) => request<void>(`/people/${id}/`, { method: 'DELETE' }),

  // All animals (active and retired) so the dashboard can show each one's status.
  animals: () => request<unknown>('/animals/?ordering=name').then(decodeList<Animal>),
  createAnimal: (input: { name: string; species: string; breed?: string }) =>
    request<Animal>('/animals/', { method: 'POST', body: JSON.stringify(input) }),
  updateAnimal: (
    id: number,
    patch: { name?: string; species?: string; breed?: string; active?: boolean },
  ) => request<Animal>(`/animals/${id}/`, { method: 'PATCH', body: JSON.stringify(patch) }),
  deleteAnimal: (id: number) => request<void>(`/animals/${id}/`, { method: 'DELETE' }),

  crops: (show = 'growing') =>
    request<unknown>(`/crops/timeline/?show=${show}`).then(decodeList<Crop>),
  cropCatalog: () => request<CropCatalogEntry[]>('/crops/catalog/'),
  createCrop: (input: CreateCropInput) =>
    request<Crop>('/crops/', { method: 'POST', body: JSON.stringify(input) }),
  updateCrop: (id: number, patch: UpdateCropInput) =>
    request<Crop>(`/crops/${id}/`, { method: 'PATCH', body: JSON.stringify(patch) }),
  deleteCrop: (id: number) => request<void>(`/crops/${id}/`, { method: 'DELETE' }),
  // Marking harvested also retires the crop's auto watering/harvest reminders.
  harvestCrop: (id: number, input: HarvestCropInput) =>
    request<Crop>(`/crops/${id}/harvest/`, { method: 'POST', body: JSON.stringify(input) }),

  // Journal: keep DRF's pagination envelope so timelines can load further pages.
  logEntries: async (params: { animal?: number; types?: string; page?: number } = {}) => {
    const q = new URLSearchParams()
    if (params.animal != null) q.set('animal', String(params.animal))
    if (params.types) q.set('types', params.types)
    if (params.page && params.page > 1) q.set('page', String(params.page))
    const qs = q.toString()
    const data = await request<unknown>(`/log-entries/${qs ? `?${qs}` : ''}`)
    if (Array.isArray(data)) return { results: data, next: null } as Paged<LogEntry>
    const env = data as { results: LogEntry[]; next: string | null }
    return { results: env.results, next: env.next } as Paged<LogEntry>
  },
  createLogEntry: (input: LogEntryInput) =>
    request<LogEntry>('/log-entries/', { method: 'POST', body: JSON.stringify(input) }),
  updateLogEntry: (id: number, patch: Partial<LogEntryInput>) =>
    request<LogEntry>(`/log-entries/${id}/`, { method: 'PATCH', body: JSON.stringify(patch) }),
  deleteLogEntry: (id: number) => request<void>(`/log-entries/${id}/`, { method: 'DELETE' }),

  // Web push (browser reminders).
  vapidPublicKey: () => request<{ key: string }>('/push/vapid-public-key/'),
  pushSubscribe: (sub: PushSubscriptionJSON) =>
    request<{ ok: boolean }>('/push/subscribe/', { method: 'POST', body: JSON.stringify(sub) }),
  pushUnsubscribe: (endpoint: string) =>
    request<void>('/push/unsubscribe/', { method: 'POST', body: JSON.stringify({ endpoint }) }),

  eggSummary: () => request<EggSummary>('/egg-records/summary/'),
  recentEggs: () => request<unknown>('/egg-records/?ordering=-date').then(decodeList<EggRecord>),
  incrementEggs: (count = 1, source?: string) =>
    request<EggRecord>('/egg-records/increment/', {
      method: 'POST',
      body: JSON.stringify({ count, ...(source ? { source } : {}) }),
    }),
}
