import { useState } from 'react'
import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useHarvestCrop } from '../api/hooks'
import type { Crop } from '../api/types'

/** Record a harvest: date + optional yield. Also retires the crop's reminders. */
export default function HarvestDialog({
  crop,
  onClose,
  onDone,
}: {
  crop: Crop
  onClose: () => void
  onDone?: (crop: Crop) => void
}) {
  const harvest = useHarvestCrop()
  const todayIso = new Date().toISOString().slice(0, 10)

  const [date, setDate] = useState(todayIso)
  const [yieldKg, setYieldKg] = useState('')
  const [note, setNote] = useState('')
  const [error, setError] = useState<string | null>(null)

  const save = async () => {
    const trimmed = yieldKg.trim()
    if (trimmed && !Number.isFinite(Number(trimmed))) {
      setError('Yield must be a number (kg).')
      return
    }
    try {
      const updated = await harvest.mutateAsync({
        id: crop.id,
        input: {
          date,
          ...(trimmed ? { yield_kg: trimmed } : {}),
          ...(note.trim() ? { note: note.trim() } : {}),
        },
      })
      onDone?.(updated as Crop)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>Harvest {crop.crop_label}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField
            label="Harvested on"
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            slotProps={{ inputLabel: { shrink: true } }}
          />
          <TextField
            label="Yield (kg, optional)"
            type="number"
            value={yieldKg}
            onChange={(e) => setYieldKg(e.target.value)}
            autoFocus
          />
          <TextField
            label="Note (optional)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            multiline
            minRows={2}
          />
          <Typography variant="caption" color="text.secondary">
            Marking the harvest also clears this crop's watering and harvest reminders.
          </Typography>
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={save} disabled={harvest.isPending}>
          Harvest
        </Button>
      </DialogActions>
    </Dialog>
  )
}
