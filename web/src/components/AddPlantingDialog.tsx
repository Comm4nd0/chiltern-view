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
import { useCreatePlanting } from '../api/hooks'

const categories = [
  { value: 'first_early', label: 'First early' },
  { value: 'second_early', label: 'Second early' },
  { value: 'maincrop', label: 'Maincrop' },
  { value: 'salad', label: 'Salad' },
]

export default function AddPlantingDialog({ onClose }: { onClose: () => void }) {
  const createPlanting = useCreatePlanting()
  const todayIso = new Date().toISOString().slice(0, 10)

  const [variety, setVariety] = useState('')
  const [category, setCategory] = useState('maincrop')
  const [plantedOn, setPlantedOn] = useState(todayIso)
  const [bed, setBed] = useState('')
  const [error, setError] = useState<string | null>(null)

  const save = async () => {
    if (!variety.trim()) {
      setError('Enter a variety.')
      return
    }
    try {
      await createPlanting.mutateAsync({
        variety: variety.trim(),
        category,
        planted_on: plantedOn,
        bed: bed.trim(),
      })
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>New potato planting</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField
            label="Variety (e.g. Maris Piper)"
            value={variety}
            onChange={(e) => setVariety(e.target.value)}
            autoFocus
            required
          />
          <TextField
            select
            label="Type"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
          >
            {categories.map((c) => (
              <MenuItem key={c.value} value={c.value}>
                {c.label}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            label="Planted on"
            type="date"
            value={plantedOn}
            onChange={(e) => setPlantedOn(e.target.value)}
            slotProps={{ inputLabel: { shrink: true } }}
          />
          <TextField label="Bed / row (optional)" value={bed} onChange={(e) => setBed(e.target.value)} />
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={save} disabled={createPlanting.isPending}>
          Add
        </Button>
      </DialogActions>
    </Dialog>
  )
}
