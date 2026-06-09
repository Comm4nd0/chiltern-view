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
  Typography,
} from '@mui/material'
import { useAnimals, useCreateTask, usePeople } from '../api/hooks'
import { useMyPersonId } from '../config'

export default function AddTaskDialog({ onClose }: { onClose: () => void }) {
  const myId = useMyPersonId()
  const people = usePeople()
  const animals = useAnimals()
  const createTask = useCreateTask()

  const [name, setName] = useState('')
  const [days, setDays] = useState('7')
  const [assignee, setAssignee] = useState(myId != null ? String(myId) : '')
  const [animal, setAnimal] = useState('')
  const [error, setError] = useState<string | null>(null)

  const save = async () => {
    const n = Number(days)
    if (!name.trim() || !Number.isFinite(n) || n <= 0) {
      setError('Enter a name and a positive interval.')
      return
    }
    try {
      await createTask.mutateAsync({
        name: name.trim(),
        recurrence_interval_days: n,
        assignee: assignee ? Number(assignee) : null,
        animal: animal ? Number(animal) : null,
      })
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>New care task</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField
            label="Task name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            required
          />
          <TextField
            label="Repeat every (days)"
            type="number"
            value={days}
            onChange={(e) => setDays(e.target.value)}
          />
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
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={save} disabled={createTask.isPending}>
          Add
        </Button>
      </DialogActions>
    </Dialog>
  )
}
