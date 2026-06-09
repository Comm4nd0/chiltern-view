import type {
  Animal,
  AuthUser,
  CareTask,
  Crop,
  CropCatalogEntry,
  EggRecord,
  EggSummary,
  Overview,
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
  recurrence_interval_days: number
  description?: string
  animal?: number | null
  assignee?: number | null
}

export interface CreateCropInput {
  crop: string
  variety?: string
  planted_on: string
  bed?: string
  quantity?: number | null
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
  completeTask: (id: number, note?: string) =>
    request<CareTask>(`/care-tasks/${id}/complete/`, {
      method: 'POST',
      body: JSON.stringify(note ? { note } : {}),
    }),
  createTask: (input: CreateTaskInput) =>
    request<CareTask>('/care-tasks/', { method: 'POST', body: JSON.stringify(input) }),

  people: () => request<unknown>('/people/?ordering=name').then(decodeList<Person>),
  createPerson: (name: string) =>
    request<Person>('/people/', { method: 'POST', body: JSON.stringify({ name }) }),
  deletePerson: (id: number) => request<void>(`/people/${id}/`, { method: 'DELETE' }),

  // All animals (active and retired) so the dashboard can show each one's status.
  animals: () => request<unknown>('/animals/?ordering=name').then(decodeList<Animal>),
  createAnimal: (input: { name: string; species: string; breed?: string }) =>
    request<Animal>('/animals/', { method: 'POST', body: JSON.stringify(input) }),
  deleteAnimal: (id: number) => request<void>(`/animals/${id}/`, { method: 'DELETE' }),

  crops: (show = 'growing') =>
    request<unknown>(`/crops/timeline/?show=${show}`).then(decodeList<Crop>),
  cropCatalog: () => request<CropCatalogEntry[]>('/crops/catalog/'),
  createCrop: (input: CreateCropInput) =>
    request<Crop>('/crops/', { method: 'POST', body: JSON.stringify(input) }),

  eggSummary: () => request<EggSummary>('/egg-records/summary/'),
  recentEggs: () => request<unknown>('/egg-records/?ordering=-date').then(decodeList<EggRecord>),
  incrementEggs: (count = 1, source?: string) =>
    request<EggRecord>('/egg-records/increment/', {
      method: 'POST',
      body: JSON.stringify({ count, ...(source ? { source } : {}) }),
    }),
}
