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

/** Create a new care task, or edit/delete an existing one when `task` is given.
 * `defaultAnimal` pre-selects the animal when adding from an animal's page. */
export default function AddTaskDialog({
  task,
  defaultAnimal,
  onClose,
}: {
  task?: CareTask
  defaultAnimal?: number
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
  const [timesPerDay, setTimesPerDay] = useState(String(task?.times_per_day ?? 1))
  // "HH:MM:SS" from the API → the <input type=time> value "HH:MM"; '' = no time.
  const [time, setTime] = useState(task?.due_time ? task.due_time.slice(0, 5) : '')
  const [repeats, setRepeats] = useState(task ? task.due_date == null : true)
  const [dueDate, setDueDate] = useState(task?.due_date ?? new Date().toISOString().slice(0, 10))
  const [assignee, setAssignee] = useState(
    task?.assignee != null ? String(task.assignee) : myId != null ? String(myId) : '',
  )
  const [animal, setAnimal] = useState(
    task?.animal != null ? String(task.animal) : defaultAnimal != null ? String(defaultAnimal) : '',
  )
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
    const timeVal = time.trim() || null
    let payload
    if (repeats) {
      const n = Number(days)
      if (!Number.isFinite(n) || n <= 0) {
        setError('Enter a positive interval.')
        return
      }
      // A clock-timed task happens once at that time; "times a day" only applies
      // to timeless tasks.
      let times = 1
      if (!timeVal) {
        times = Number(timesPerDay)
        if (!Number.isInteger(times) || times <= 0) {
          setError('Times a day must be a positive number.')
          return
        }
      }
      payload = {
        ...base,
        recurrence_interval_days: n,
        times_per_day: times,
        due_date: null,
        due_time: timeVal,
      }
    } else {
      if (!dueDate) {
        setError('Pick a due date.')
        return
      }
      payload = { ...base, due_date: dueDate, times_per_day: 1, due_time: null }
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
            <>
              <Stack direction="row" spacing={2}>
                <TextField
                  label="Repeat every (days)"
                  type="number"
                  value={days}
                  onChange={(e) => setDays(e.target.value)}
                  fullWidth
                />
                <TextField
                  label="Time (optional)"
                  type="time"
                  value={time}
                  onChange={(e) => setTime(e.target.value)}
                  helperText="e.g. 07:30 to feed the dog"
                  fullWidth
                  slotProps={{ inputLabel: { shrink: true } }}
                />
              </Stack>
              {/* A clock time means "once at that time", so times-a-day only shows
                  for timeless tasks (e.g. collect the eggs, sometime today). */}
              {!time.trim() && (
                <TextField
                  label="Times a day"
                  type="number"
                  value={timesPerDay}
                  onChange={(e) => setTimesPerDay(e.target.value)}
                  helperText="e.g. 4 feeds a day"
                  fullWidth
                />
              )}
            </>
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
