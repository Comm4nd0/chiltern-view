import { useMemo, useState } from 'react'
import { Box, Chip, Fab, Snackbar, Stack, Typography } from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import { useCompleteTask, useDashboard, usePeople } from '../api/hooks'
import { useMyPersonId } from '../config'
import QueryBoundary from '../components/QueryBoundary'
import CareTaskCard from '../components/CareTaskCard'
import AddTaskDialog from '../components/AddTaskDialog'
import type { CareTask } from '../api/types'

export default function DashboardPage() {
  const myId = useMyPersonId()
  const people = usePeople()
  const [filter, setFilter] = useState<string | undefined>(myId != null ? String(myId) : undefined)
  const dashboard = useDashboard(filter)
  const complete = useCompleteTask()
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editing, setEditing] = useState<CareTask | null>(null)
  const [snack, setSnack] = useState<string | null>(null)
  const [completingId, setCompletingId] = useState<number | null>(null)

  const chips = useMemo(() => {
    const list: { label: string; value: string | undefined }[] = [
      { label: 'Everyone', value: undefined },
    ]
    for (const p of people.data ?? []) {
      list.push({ label: p.id === myId ? `${p.name} (me)` : p.name, value: String(p.id) })
    }
    list.push({ label: 'Unassigned', value: 'unassigned' })
    return list
  }, [people.data, myId])

  const onComplete = async (id: number, name: string) => {
    setCompletingId(id)
    try {
      await complete.mutateAsync({ id })
      setSnack(`Marked "${name}" done`)
    } catch (e) {
      setSnack(e instanceof Error ? e.message : 'Failed')
    } finally {
      setCompletingId(null)
    }
  }

  return (
    <Box>
      <Stack direction="row" spacing={1} sx={{ overflowX: 'auto', pb: 1, mb: 1 }}>
        {chips.map((c) => (
          <Chip
            key={c.value ?? 'everyone'}
            label={c.label}
            color={filter === c.value ? 'primary' : 'default'}
            variant={filter === c.value ? 'filled' : 'outlined'}
            onClick={() => setFilter(c.value)}
          />
        ))}
      </Stack>

      <QueryBoundary query={dashboard}>
        {(tasks) =>
          tasks.length === 0 ? (
            <Typography align="center" color="text.secondary" sx={{ mt: 8 }}>
              Nothing on the list here.
            </Typography>
          ) : (
            <Stack spacing={1}>
              {tasks.map((t) => (
                <CareTaskCard
                  key={t.id}
                  task={t}
                  completing={completingId === t.id}
                  onComplete={() => onComplete(t.id, t.name)}
                  onEdit={() => setEditing(t)}
                />
              ))}
            </Stack>
          )
        }
      </QueryBoundary>

      <Fab
        color="primary"
        sx={{ position: 'fixed', bottom: 24, right: 24 }}
        onClick={() => setDialogOpen(true)}
        aria-label="Add task"
      >
        <AddIcon />
      </Fab>
      {(dialogOpen || editing) && (
        <AddTaskDialog
          task={editing ?? undefined}
          onClose={() => {
            setDialogOpen(false)
            setEditing(null)
          }}
        />
      )}
      <Snackbar
        open={snack != null}
        autoHideDuration={3000}
        onClose={() => setSnack(null)}
        message={snack ?? ''}
      />
    </Box>
  )
}
