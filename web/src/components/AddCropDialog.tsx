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
import { useCreateCrop, useCropCatalog } from '../api/hooks'

export default function AddCropDialog({ onClose }: { onClose: () => void }) {
  const createCrop = useCreateCrop()
  const catalog = useCropCatalog()
  const todayIso = new Date().toISOString().slice(0, 10)

  const [crop, setCrop] = useState('')
  const [variety, setVariety] = useState('')
  const [plantedOn, setPlantedOn] = useState(todayIso)
  const [bed, setBed] = useState('')
  const [error, setError] = useState<string | null>(null)

  const save = async () => {
    if (!crop) {
      setError('Pick a crop.')
      return
    }
    try {
      await createCrop.mutateAsync({
        crop,
        variety: variety.trim(),
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
      <DialogTitle>New crop</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField
            select
            label="Crop"
            value={crop}
            onChange={(e) => setCrop(e.target.value)}
            autoFocus
            helperText={catalog.isError ? 'Could not load the crop list' : undefined}
          >
            {(catalog.data ?? []).map((c) => (
              <MenuItem key={c.key} value={c.key}>
                {c.label}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            label="Variety (optional, e.g. Maris Piper)"
            value={variety}
            onChange={(e) => setVariety(e.target.value)}
          />
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
        <Button variant="contained" onClick={save} disabled={createCrop.isPending}>
          Add
        </Button>
      </DialogActions>
    </Dialog>
  )
}
