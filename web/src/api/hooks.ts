import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { api } from './client'

export const keys = {
  dashboard: (assignee?: string) => ['dashboard', assignee ?? 'all'] as const,
  people: ['people'] as const,
  animals: ['animals'] as const,
  potatoes: (show: string) => ['potatoes', show] as const,
  eggSummary: ['eggs', 'summary'] as const,
  eggRecent: ['eggs', 'recent'] as const,
}

export function useOverview() {
  return useQuery({ queryKey: ['overview'], queryFn: api.overview })
}

export function useDashboard(assignee?: string) {
  return useQuery({ queryKey: keys.dashboard(assignee), queryFn: () => api.dashboard(assignee) })
}

export function usePeople() {
  return useQuery({ queryKey: keys.people, queryFn: api.people })
}

export function useAnimals() {
  return useQuery({ queryKey: keys.animals, queryFn: api.animals })
}

export function usePotatoTimeline(show = 'growing') {
  return useQuery({ queryKey: keys.potatoes(show), queryFn: () => api.potatoTimeline(show) })
}

export function useEggSummary() {
  return useQuery({ queryKey: keys.eggSummary, queryFn: api.eggSummary })
}

export function useRecentEggs() {
  return useQuery({ queryKey: keys.eggRecent, queryFn: api.recentEggs })
}

export function useCompleteTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, note }: { id: number; note?: string }) => api.completeTask(id, note),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}

export function useCreateTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: api.createTask,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}

export function useCreatePerson() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (name: string) => api.createPerson(name),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: keys.people })
      qc.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}

export function useDeletePerson() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => api.deletePerson(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: keys.people })
      qc.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}

export function useCreatePlanting() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: api.createPlanting,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['potatoes'] })
      qc.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}

export function useIncrementEggs() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ count, source }: { count: number; source?: string }) =>
      api.incrementEggs(count, source),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['eggs'] })
      qc.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}
