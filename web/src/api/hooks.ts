import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { api } from './client'
import type { UpdateTaskInput } from './client'

export const keys = {
  dashboard: (assignee?: string) => ['dashboard', assignee ?? 'all'] as const,
  people: ['people'] as const,
  animals: ['animals'] as const,
  crops: (show: string) => ['crops', show] as const,
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

export function useCreateAnimal() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: api.createAnimal,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: keys.animals })
      qc.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}

export function useDeleteAnimal() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => api.deleteAnimal(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: keys.animals })
      qc.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}

export function useCrops(show = 'growing') {
  return useQuery({ queryKey: keys.crops(show), queryFn: () => api.crops(show) })
}

export function useCropCatalog() {
  return useQuery({
    queryKey: ['cropCatalog'],
    queryFn: api.cropCatalog,
    staleTime: 1000 * 60 * 60,
  })
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

export function useUpdateTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, patch }: { id: number; patch: UpdateTaskInput }) => api.updateTask(id, patch),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}

export function useDeleteTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => api.deleteTask(id),
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

export function useCreateCrop() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: api.createCrop,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['crops'] })
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
