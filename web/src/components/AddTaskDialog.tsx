import { useState } from 'react'
import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  MenuItem,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material'
import {
  useAnimals,
  useCreateTask,
  useDeleteTask,
  usePeople,
  useUpdateTask,
} from '../api/hooks'
import { useMyPersonId } from '../config'
import type { CareTask } from '../api/types'

/** Create a new care task, or edit/delete an existing one when `task` is given. */
export default function AddTaskDialog({
  task,
  onClose,
}: {
  task?: CareTask
  onClose: () => void
}) {
  const editing = task != null
  const myId = useMyPersonId()
  const people = usePeople()
  const animals = useAnimals()
  const createTask = useCreateTask()
  const updateTask = useUpdateTask()
  const deleteTask = useDeleteTask()

  const [name, setName] = useState(task?.name ?? '')
  const [days, setDays] = useState(String(task?.recurrence_interval_days ?? 7))
  const [repeats, setRepeats] = useState(task ? task.due_date == null : true)
  const [dueDate, setDueDate] = useState(task?.due_date ?? new Date().toISOString().slice(0, 10))
  const [assignee, setAssignee] = useState(
    task?.assignee != null ? String(task.assignee) : myId != null ? String(myId) : '',
  )
  const [animal, setAnimal] = useState(task?.animal != null ? String(task.animal) : '')
  const [error, setError] = useState<string | null>(null)

  const busy = createTask.isPending || updateTask.isPending || deleteTask.isPending

  const save = async () => {
    if (!name.trim()) {
      setError('Enter a task name.')
      return
    }
    const base = {
      name: name.trim(),
      assignee: assignee ? Number(assignee) : null,
      animal: animal ? Number(animal) : null,
    }
    let payload
    if (repeats) {
      const n = Number(days)
      if (!Number.isFinite(n) || n <= 0) {
        setError('Enter a positive interval.')
        return
      }
      payload = { ...base, recurrence_interval_days: n, due_date: null }
    } else {
      if (!dueDate) {
        setError('Pick a due date.')
        return
      }
      payload = { ...base, due_date: dueDate }
    }
    try {
      if (editing) await updateTask.mutateAsync({ id: task.id, patch: payload })
      else await createTask.mutateAsync(payload)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  const remove = async () => {
    if (!editing) return
    try {
      await deleteTask.mutateAsync(task.id)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to delete.')
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>{editing ? 'Edit task' : 'New care task'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField
            label="Task name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            required
          />
          <ToggleButtonGroup
            exclusive
            fullWidth
            color="primary"
            size="small"
            value={repeats ? 'repeats' : 'oneoff'}
            onChange={(_, v) => {
              if (v) setRepeats(v === 'repeats')
            }}
          >
            <ToggleButton value="repeats">Repeats</ToggleButton>
            <ToggleButton value="oneoff">One-off</ToggleButton>
          </ToggleButtonGroup>
          {repeats ? (
            <TextField
              label="Repeat every (days)"
              type="number"
              value={days}
              onChange={(e) => setDays(e.target.value)}
            />
          ) : (
            <TextField
              label="Due date"
              type="date"
              value={dueDate}
              onChange={(e) => setDueDate(e.target.value)}
              slotProps={{ inputLabel: { shrink: true } }}
            />
          )}
          <TextField
            select
            label="Assign to"
            value={assignee}
            onChange={(e) => setAssignee(e.target.value)}
          >
            <MenuItem value="">Anyone</MenuItem>
            {(people.data ?? []).map((p) => (
              <MenuItem key={p.id} value={String(p.id)}>
                {p.name}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            select
            label="Animal (optional)"
            value={animal}
            onChange={(e) => setAnimal(e.target.value)}
          >
            <MenuItem value="">Whole holding</MenuItem>
            {(animals.data ?? []).map((a) => (
              <MenuItem key={a.id} value={String(a.id)}>
                {a.name}
              </MenuItem>
            ))}
          </TextField>
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        {editing && (
          <Button color="error" onClick={remove} disabled={busy} sx={{ mr: 'auto' }}>
            Delete
          </Button>
        )}
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={save} disabled={busy}>
          {editing ? 'Save' : 'Add'}
        </Button>
      </DialogActions>
    </Dialog>
  )
}
