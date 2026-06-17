import { useState } from 'react'
import {
  Button,
  Card,
  CardContent,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useCreateWeight, useDeleteWeight, useWeights } from '../api/hooks'
import { fmtDate } from '../format'

/** Weight log for one animal: latest reading + change, recent history, and a
 * quick "log weight" dialog. Pairs with the health journal. */
export default function WeightCard({ animalId }: { animalId: number }) {
  const weights = useWeights(animalId)
  const create = useCreateWeight()
  const remove = useDeleteWeight()
  const todayIso = new Date().toISOString().slice(0, 10)
  const [open, setOpen] = useState(false)
  const [kg, setKg] = useState('')
  const [date, setDate] = useState(todayIso)
  const [note, setNote] = useState('')
  const [error, setError] = useState<string | null>(null)

  // API returns oldest-first; newest reading is last.
  const list = weights.data ?? []
  const latest = list.length > 0 ? list[list.length - 1] : null
  const previous = list.length > 1 ? list[list.length - 2] : null
  const delta = latest && previous ? Number(latest.weight_kg) - Number(previous.weight_kg) : null

  const save = async () => {
    const value = Number(kg)
    if (!kg.trim() || Number.isNaN(value) || value < 0) {
      setError('Enter a weight in kg.')
      return
    }
    try {
      await create.mutateAsync({ animal: animalId, weight_kg: kg.trim(), date, note: note.trim() })
      setOpen(false)
      setKg('')
      setNote('')
      setError(null)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  return (
    <Card>
      <CardContent>
        <Stack direction="row" alignItems="center" sx={{ mb: 1 }}>
          <Typography variant="h6" sx={{ flex: 1 }}>
            Weight
          </Typography>
          <Button size="small" variant="contained" onClick={() => setOpen(true)}>
            Log weight
          </Button>
        </Stack>
        {latest ? (
          <>
            <Stack direction="row" alignItems="baseline" spacing={1}>
              <Typography variant="h4" fontWeight={700}>
                {Number(latest.weight_kg)} kg
              </Typography>
              {delta != null && delta !== 0 && (
                <Typography
                  variant="body2"
                  sx={{ color: delta > 0 ? 'success.main' : 'warning.main', fontWeight: 600 }}
                >
                  {delta > 0 ? '▲' : '▼'} {Math.abs(Math.round(delta * 100) / 100)} kg
                </Typography>
              )}
              <Typography variant="caption" color="text.secondary">
                {fmtDate(latest.date)}
              </Typography>
            </Stack>
            {list.length > 1 && (
              <Stack divider={<Divider />} sx={{ mt: 1 }}>
                {[...list]
                  .reverse()
                  .slice(0, 6)
                  .map((w) => (
                    <Stack
                      key={w.id}
                      direction="row"
                      alignItems="center"
                      spacing={1}
                      sx={{ py: 0.75 }}
                    >
                      <Typography variant="body2" sx={{ flex: 1 }} color="text.secondary">
                        {fmtDate(w.date, { day: 'numeric', month: 'short', year: 'numeric' })}
                        {w.note ? ` · ${w.note}` : ''}
                      </Typography>
                      <Typography variant="body2" fontWeight={600}>
                        {Number(w.weight_kg)} kg
                      </Typography>
                      <Button
                        size="small"
                        color="error"
                        onClick={() => remove.mutate(w.id)}
                        sx={{ minWidth: 0 }}
                        aria-label="Delete weight"
                      >
                        ✕
                      </Button>
                    </Stack>
                  ))}
              </Stack>
            )}
          </>
        ) : (
          <Typography color="text.secondary" sx={{ py: 1 }}>
            No weights logged yet.
          </Typography>
        )}
      </CardContent>

      {open && (
        <Dialog open onClose={() => setOpen(false)} fullWidth maxWidth="xs">
          <DialogTitle>Log weight</DialogTitle>
          <DialogContent>
            <Stack spacing={2} sx={{ mt: 1 }}>
              <TextField
                label="Weight (kg)"
                type="number"
                value={kg}
                onChange={(e) => setKg(e.target.value)}
                autoFocus
              />
              <TextField
                label="When"
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                slotProps={{ inputLabel: { shrink: true } }}
              />
              <TextField
                label="Note (optional)"
                value={note}
                onChange={(e) => setNote(e.target.value)}
              />
              {error && (
                <Typography color="error" variant="body2">
                  {error}
                </Typography>
              )}
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setOpen(false)}>Cancel</Button>
            <Button variant="contained" onClick={save} disabled={create.isPending}>
              Save
            </Button>
          </DialogActions>
        </Dialog>
      )}
    </Card>
  )
}
