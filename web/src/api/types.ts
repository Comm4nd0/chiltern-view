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
}

export interface CareTask {
  id: number
  name: string
  description: string
  animal: number | null
  animal_name: string | null
  assignee: number | null
  assignee_name: string | null
  recurrence_interval_days: number
  last_completed: string | null
  active: boolean
  next_due: string
  days_overdue: number
  status: 'overdue' | 'due_today' | 'upcoming'
}

export interface CropStage {
  label: string
  date: string
}

export interface Crop {
  id: number
  crop: string
  crop_label: string
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

export interface OverviewTask {
  id: number
  name: string
  assignee_name: string | null
  days_overdue: number
  status: 'overdue' | 'due_today' | 'upcoming'
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
}
