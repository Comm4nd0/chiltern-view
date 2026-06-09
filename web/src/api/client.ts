import type {
  Animal,
  CareTask,
  Crop,
  CropCatalogEntry,
  EggRecord,
  EggSummary,
  Overview,
  Person,
} from './types'

// Same-origin in production (nginx proxies /api to the backend); the Vite dev
// server proxies /api too. Override with VITE_API_BASE if ever needed.
const BASE = import.meta.env.VITE_API_BASE ?? '/api'

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })
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

  animals: () =>
    request<unknown>('/animals/?active=true&ordering=name').then(decodeList<Animal>),
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
