export interface Person {
  id: number
  name: string
}

export interface Animal {
  id: number
  name: string
  species: string
  species_display: string
  breed: string
  date_of_birth: string | null
  active: boolean
}

export interface AuthUser {
  id: number
  username: string
  person_id: number | null
  person_name: string | null
}

export interface CareTask {
  id: number
  name: string
  description: string
  animal: number | null
  animal_name: string | null
  /** Animal type this task belongs to (e.g. 'chicken' — collect the eggs); '' if not type-level. */
  species: string
  species_display: string
  assignee: number | null
  assignee_name: string | null
  recurrence_interval_days: number
  /** How many times the task needs doing on its due day (1 = once). */
  times_per_day: number
  /** Completions recorded so far today. */
  times_done_today: number
  last_completed: string | null
  due_date: string | null
  /** Clock time the task is due / its reminder fires ("HH:MM:SS"); null = anytime that day. */
  due_time: string | null
  active: boolean
  next_due: string
  days_overdue: number
  status: 'overdue' | 'due_today' | 'upcoming'
  /** True when recent/forecast rain covers this watering job for today. */
  rain_deferred: boolean
  weather_note: string | null
}

export interface CropStage {
  label: string
  date: string
}

export interface Crop {
  id: number
  crop: string
  crop_label: string
  /** Botanical family code (e.g. 'solanaceae'); null for an unknown crop. */
  family: string | null
  family_label: string | null
  variety: string
  planted_on: string
  quantity: number | null
  bed: string
  expected_harvest: string | null
  harvested_on: string | null
  yield_kg: string | null
  notes: string
  estimated_harvest: string
  current_stage: string
  progress: number
  stages: CropStage[]
}

export interface CropCatalogEntry {
  key: string
  label: string
  days_to_harvest: number
  family: string | null
  family_label: string | null
  stages: { label: string; fraction: number }[]
}

export interface EggRecord {
  id: number
  date: string
  count: number
  source: string
  notes: string
}

export interface EggSummary {
  today: number
  this_week: number
  this_month: number
  total: number
}

export interface EggTrendPoint {
  date: string
  count: number
}

export interface EggTrend {
  days: EggTrendPoint[]
  total: number
  average: number
  best_day: EggTrendPoint | null
}

export interface HarvestRecord {
  id: number
  crop: string
  label: string
  variety: string
  bed: string
  harvested_on: string
  yield_kg: number | null
}

export interface CropYield {
  crop: string
  label: string
  count: number
  total_kg: number
}

export interface HarvestHistory {
  harvests: HarvestRecord[]
  by_crop: CropYield[]
  total_kg: number
}

export interface BedHistory {
  bed: string
  last_crop: string
  last_family: string | null
  last_family_label: string | null
  last_planted_on: string
  growing: boolean
  recent_families: string[]
}

export interface BedsResponse {
  beds: BedHistory[]
}

export type LogEntryType = 'general' | 'health' | 'feeding' | 'breeding' | 'task_completed'

export interface LogEntry {
  id: number
  entry_type: LogEntryType
  entry_type_display: string
  note: string
  /** Medicine given (health entries); '' when none. */
  medicine: string
  withdrawal_days: number | null
  /** Last day produce from the animal must not be eaten, or null. */
  withdrawal_until: string | null
  withdrawal_active: boolean
  animal: number | null
  animal_name: string | null
  care_task: number | null
  care_task_name: string | null
  created_by: number | null
  created_by_name: string | null
  occurred_on: string
  created_at: string
}

export interface WeightRecord {
  id: number
  animal: number
  date: string
  weight_kg: string
  note: string
}

export interface Withdrawal {
  id: number
  animal: number | null
  animal_name: string | null
  medicine: string
  until: string
}

/** A page of a DRF-paginated list, keeping `next` so timelines can load more. */
export interface Paged<T> {
  results: T[]
  next: string | null
}

export interface OverviewTask {
  id: number
  name: string
  assignee_name: string | null
  days_overdue: number
  status: 'overdue' | 'due_today' | 'upcoming'
  rain_deferred: boolean
  weather_note: string | null
}

export interface WeatherDay {
  date: string
  tmin: number | null
  tmax: number | null
  precip_mm: number
  precip_prob: number | null
  frost: boolean
}

export interface FrostWarning {
  nights: string[]
  crops: string[]
  message: string
}

export interface Weather {
  location: string
  fetched_at: string
  recent_rain_mm: number
  today: WeatherDay | null
  days: WeatherDay[]
  stale: boolean
  frost_warning: FrostWarning | null
}

export interface OverviewActivityEntry {
  id: number
  entry_type: LogEntryType
  entry_type_display: string
  note: string
  animal: number | null
  animal_name: string | null
  occurred_on: string
  created_by_name: string | null
}

export interface Overview {
  tasks: {
    overdue: number
    due_today: number
    upcoming: number
    per_person: Record<string, number>
    top: OverviewTask[]
  }
  animals: { total: number; by_species: Record<string, number> }
  crops: { growing: number; next_harvest: { label: string; date: string } | null }
  eggs: { today: number; this_week: number }
  withdrawals: Withdrawal[]
  activity: OverviewActivityEntry[]
  weather: Weather | null
}
